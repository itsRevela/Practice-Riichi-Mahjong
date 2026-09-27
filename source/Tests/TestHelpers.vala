using Gee;

// Shared helpers for the unit tests.

private int test_next_tile_id = 1000;

// Parses compact tile notation into tiles with unique IDs.
// Digits are followed by their suit: m = man, p = pin, s = sou, z = honors.
// Honors: 1z-4z = East, South, West, North; 5z-7z = Haku, Hatsu, Chun.
// A 0 in a suit means a red five (aka dora), e.g. "0p" is a red 5-pin.
private ArrayList<Tile> test_tiles(string notation)
{
    ArrayList<Tile> tiles = new ArrayList<Tile>();
    ArrayList<int> pending = new ArrayList<int>();

    for (int i = 0; i < notation.length; i++)
    {
        char c = notation[i];

        if (c >= '0' && c <= '9')
        {
            pending.add(c - '0');
            continue;
        }

        TileType first;
        if (c == 'm')
            first = TileType.MAN1;
        else if (c == 'p')
            first = TileType.PIN1;
        else if (c == 's')
            first = TileType.SOU1;
        else if (c == 'z')
            first = TileType.TON;
        else
            error("Invalid tile notation '%s'", notation);

        foreach (int n in pending)
        {
            bool red = n == 0;
            int number = red ? 5 : n;
            if (c == 'z' && (red || number > 7))
                error("Invalid honor tile in '%s'", notation);

            TileType type = (TileType)((int)first + number - 1);
            tiles.add(new Tile(test_next_tile_id++, type, red));
        }

        pending.clear();
    }

    if (pending.size != 0)
        error("Tile notation '%s' is missing a trailing suit letter", notation);

    return tiles;
}

private RoundStateCall test_call(RoundStateCall.CallType type, string notation, int discarder_index)
{
    ArrayList<Tile> tiles = test_tiles(notation);
    Tile? call_tile = type == RoundStateCall.CallType.CLOSED_KAN ? null : tiles[0];
    return new RoundStateCall(type, tiles, call_tile, discarder_index);
}

// Describes a finished hand for the scoring engine. The winner is always
// player 0; "concealed" excludes the winning tile.
private class TestHand : Object
{
    public string concealed { get; set; default = ""; }
    public string win { get; set; default = ""; }
    public bool ron { get; set; default = true; }
    public bool dealer { get; set; default = false; }
    public Wind seat_wind { get; set; default = Wind.WEST; }
    public Wind round_wind { get; set; default = Wind.EAST; }
    public bool riichi { get; set; default = false; }
    public string dora_indicators { get; set; default = ""; }
    public ArrayList<RoundStateCall> calls = new ArrayList<RoundStateCall>();

    public Scoring score()
    {
        PlayerStateContext player = new PlayerStateContext
        (
            0,
            test_tiles(concealed),
            new ArrayList<Tile>(),
            calls,
            seat_wind,
            dealer,
            riichi,
            false,
            false,
            false,
            false,
            false,
            -1
        );

        RoundStateContext round = new RoundStateContext
        (
            round_wind,
            test_tiles(dora_indicators),
            new ArrayList<Tile>(),
            ron,
            test_tiles(win)[0],
            false,
            false,
            false,
            true
        );

        return TileRules.get_score(player, round);
    }
}

private void expect_int(string what, int expected, int actual)
{
    if (expected == actual)
        return;

    stderr.printf("FAIL %s: %s: expected %d, got %d\n", Test.get_path(), what, expected, actual);
    Test.fail();
}

private void expect_true(string what, bool condition)
{
    if (condition)
        return;

    stderr.printf("FAIL %s: expected %s\n", Test.get_path(), what);
    Test.fail();
}

private void expect_string(string what, string expected, string actual)
{
    if (expected == actual)
        return;

    stderr.printf("FAIL %s: %s: expected \"%s\", got \"%s\"\n", Test.get_path(), what, expected, actual);
    Test.fail();
}

private bool scoring_has_yaku(Scoring score, YakuType type)
{
    if (score.yaku == null)
        return false;

    foreach (Yaku y in score.yaku)
        if (y.yaku_type == type)
            return true;

    return false;
}
