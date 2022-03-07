const TwotterBNB = artifacts.require("TwotterBNB");
const BalanceService = artifacts.require("BalanceService");

contract('TwotterBNB', ([minter]) => {
    beforeEach(async () => {
        this.balanceService = await BalanceService.new();
        this.twotter = await TwotterBNB.new(this.balanceService.address);
        //await this.balanceService.addUnblocked(this.twotter.address);
    });

    it("First Game", async () => {
        const counterGame = await this.twotter._counterGame();
        const game = await this.twotter.getGame(counterGame);
        const status = game[1].toString();
        const winner = game[2].toString();
        const closeTimestamp = game[3].toString();
        console.log(status);
        console.log(winner);
        console.log(closeTimestamp);
        assert.equal(
            counterGame,
            0,
            "It is first game"
        );
    });

});
