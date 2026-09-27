using Engine;
using Gee;

// Builds random winning hands for Point Calculation Practice.
//
// Hands are assembled meld by meld from a real 136-tile set that has one red
// five per suit, so tile counts are always legal. Some melds become calls
// (chii, pon, kans), and the round context (winds, dealer, riichi, dora,
// situational yaku) is rolled to match. The finished hand is scored by
// TileRules; hands without a yaku are thrown away and rebuilt.
public class PointCalcHandGenerator
{
    private const int MAX_ATTEMPTS = 1000;
    private const int PLAYER_INDEX = 0;
    private const int LEFT_PLAYER_INDEX = 3; // Chii can only be called from the player on the left

    private const float CHIITOI_CHANCE = 0.07f;
    private const float SEQUENCE_CHANCE = 0.62f;
    private const float HONOR_TRIPLET_CHANCE = 0.3f;
    private const float HONOR_PAIR_CHANCE = 0.25f;
    private const float KAN_CHANCE = 0.12f;
    private const float CLOSED_KAN_CHANCE = 0.4f;
    private const float OPEN_KAN_CHANCE = 0.3f; // The rest are added kans
    private const float OPEN_HAND_CHANCE = 0.45f;
    private const float CALL_CHANCE = 0.5f;
    private const float EAST_ROUND_CHANCE = 0.55f;
    private const float RIICHI_CHANCE = 0.6f;
    private const float IPPATSU_CHANCE = 0.15f;
    private const float RINSHAN_CHANCE = 0.3f;
    private const float LAST_TILE_CHANCE = 0.06f;
    private const float CHANKAN_CHANCE = 0.2f;

    private RandomClass rnd;

    public PointCalcHandGenerator(RandomClass rnd)
    {
        this.rnd = rnd;
    }

    // Returns null only if no hand with a yaku turned up, which should never happen in practice
    public PointCalcQuestion? generate()
    {
        for (int i = 0; i < MAX_ATTEMPTS; i++)
        {
            PointCalcQuestion? question = try_generate();
            if (question != null)
                return question;
        }

        warning("Could not generate a hand with a yaku in %d attempts", MAX_ATTEMPTS);
        return null;
    }

    private PointCalcQuestion? try_generate()
    {
        PointCalcTilePool pool = new PointCalcTilePool(rnd);
        ArrayList<Tile> concealed = new ArrayList<Tile>(); // Includes the winning tile until it is picked
        ArrayList<RoundStateCall> calls = new ArrayList<RoundStateCall>();

        bool built = chance(CHIITOI_CHANCE) ? build_chiitoi(pool, concealed) : build_standard(pool, concealed, calls);
        if (!built)
            return null;

        int kan_count = calls.size - count_calls(calls, RoundStateCall.CallType.CHII) - count_calls(calls, RoundStateCall.CallType.PON);
        bool closed = TileRules.is_closed_hand(calls);

        Tile win_tile = concealed[rnd.int_range(0, concealed.size)];
        concealed.remove(win_tile);

        Wind round_wind = chance(EAST_ROUND_CHANCE) ? Wind.EAST : Wind.SOUTH;
        Wind seat_wind = (Wind)rnd.int_range(0, 4);
        bool dealer = seat_wind == Wind.EAST;
        bool ron = rnd.next_bool();

        bool riichi = closed && chance(RIICHI_CHANCE);
        // A rinshan win means a kan was just declared, which ends ippatsu
        bool rinshan = !ron && kan_count > 0 && chance(RINSHAN_CHANCE);
        bool ippatsu = riichi && !rinshan && chance(IPPATSU_CHANCE);
        // The kan replacement tile is never the last tile of the wall
        bool last_tile = !rinshan && chance(LAST_TILE_CHANCE);

        // Every kan flips an extra indicator
        ArrayList<Tile> dora = pool.take_random(1 + kan_count);
        ArrayList<Tile> ura_dora = pool.take_random(1 + kan_count);

        // Chankan robs the fourth copy of a tile as another player upgrades their pon,
        // so the other three copies must be unaccounted for. The last discard can't be robbed.
        bool chankan = ron && !last_tile && pool.count(win_tile.tile_type) == 3 && chance(CHANKAN_CHANCE);

        PlayerStateContext player = new PlayerStateContext
        (
            PLAYER_INDEX,
            concealed,
            new ArrayList<Tile>(),
            calls,
            seat_wind,
            dealer,
            riichi,
            false,
            false,
            ippatsu,
            false,
            false,
            -1
        );

        RoundStateContext round = new RoundStateContext
        (
            round_wind,
            dora,
            ura_dora,
            ron,
            win_tile,
            last_tile,
            rinshan,
            chankan,
            true
        );

        Scoring scoring = TileRules.get_score(player, round);
        if (!scoring.valid || !scoring.has_valid_yaku())
            return null;

        return new PointCalcQuestion(player, round, scoring);
    }

    private bool build_chiitoi(PointCalcTilePool pool, ArrayList<Tile> concealed)
    {
        ArrayList<TileType> used = new ArrayList<TileType>();

        while (used.size < 7)
        {
            TileType type = random_type(HONOR_PAIR_CHANCE);
            if (used.contains(type))
                continue;

            ArrayList<Tile>? pair = pool.take(type, 2);
            if (pair == null)
                return false;

            used.add(type);
            concealed.add_all(pair);
        }

        return true;
    }

    private bool build_standard(PointCalcTilePool pool, ArrayList<Tile> concealed, ArrayList<RoundStateCall> calls)
    {
        bool open_hand = chance(OPEN_HAND_CHANCE);

        for (int i = 0; i < 4; i++)
        {
            bool sequence = chance(SEQUENCE_CHANCE);
            ArrayList<Tile>? meld = sequence ? take_sequence(pool) : pool.take(random_type(HONOR_TRIPLET_CHANCE), 3);
            if (meld == null)
                return false;

            if (!sequence && chance(KAN_CHANCE))
            {
                Tile? fourth = pool.take_one(meld[0].tile_type);
                if (fourth != null)
                {
                    meld.add(fourth);
                    calls.add(make_kan_call(meld));
                    continue;
                }
            }

            if (open_hand && chance(CALL_CHANCE))
                calls.add(make_call(meld, sequence));
            else
                concealed.add_all(meld);
        }

        ArrayList<Tile>? pair = pool.take(random_type(HONOR_PAIR_CHANCE), 2);
        if (pair == null)
            return false;

        concealed.add_all(pair);
        return true;
    }

    private ArrayList<Tile>? take_sequence(PointCalcTilePool pool)
    {
        int suit = rnd.int_range(0, 3);
        int start = rnd.int_range(0, 7); // Sequences start on 1 through 7
        int first = (int)TileType.MAN1 + suit * 9 + start;

        TileType[] types = { (TileType)first, (TileType)(first + 1), (TileType)(first + 2) };
        return pool.take_each(types);
    }

    private RoundStateCall make_kan_call(ArrayList<Tile> tiles)
    {
        float roll = rnd.next_float();
        if (roll < CLOSED_KAN_CHANCE)
            return new RoundStateCall(RoundStateCall.CallType.CLOSED_KAN, tiles, null, PLAYER_INDEX);

        RoundStateCall.CallType type = roll < CLOSED_KAN_CHANCE + OPEN_KAN_CHANCE ?
            RoundStateCall.CallType.OPEN_KAN : RoundStateCall.CallType.LATE_KAN;
        return new RoundStateCall(type, tiles, random_tile(tiles), random_opponent());
    }

    private RoundStateCall make_call(ArrayList<Tile> tiles, bool sequence)
    {
        if (sequence)
            return new RoundStateCall(RoundStateCall.CallType.CHII, tiles, random_tile(tiles), LEFT_PLAYER_INDEX);
        return new RoundStateCall(RoundStateCall.CallType.PON, tiles, random_tile(tiles), random_opponent());
    }

    private static int count_calls(ArrayList<RoundStateCall> calls, RoundStateCall.CallType type)
    {
        int count = 0;
        foreach (RoundStateCall call in calls)
            if (call.call_type == type)
                count++;
        return count;
    }

    private TileType random_type(float honor_chance)
    {
        if (chance(honor_chance))
            return (TileType)rnd.int_range((int)TileType.TON, (int)TileType.CHUN + 1);
        return (TileType)rnd.int_range((int)TileType.MAN1, (int)TileType.SOU9 + 1);
    }

    private Tile random_tile(ArrayList<Tile> tiles)
    {
        return tiles[rnd.int_range(0, tiles.size)];
    }

    private int random_opponent()
    {
        return rnd.int_range(1, 4);
    }

    private bool chance(float probability)
    {
        return rnd.next_float() < probability;
    }
}

// The physical tiles not yet dealt into the generated hand
private class PointCalcTilePool
{
    private ArrayList<Tile> tiles = new ArrayList<Tile>();
    private RandomClass rnd;

    public PointCalcTilePool(RandomClass rnd)
    {
        this.rnd = rnd;

        for (int i = 0; i < 136; i++)
        {
            TileType type = (TileType)(i / 4 + 1);
            // One copy of each five is red (aka dora), as in the game's default rules
            bool red = i % 4 == 0 && (type == TileType.MAN5 || type == TileType.PIN5 || type == TileType.SOU5);
            tiles.add(new Tile(i, type, red));
        }
    }

    public int count(TileType type)
    {
        int count = 0;
        foreach (Tile tile in tiles)
            if (tile.tile_type == type)
                count++;
        return count;
    }

    // Removes a random remaining copy of the type, or returns null if none are left
    public Tile? take_one(TileType type)
    {
        ArrayList<Tile> copies = new ArrayList<Tile>();
        foreach (Tile tile in tiles)
            if (tile.tile_type == type)
                copies.add(tile);

        if (copies.size == 0)
            return null;

        Tile taken = copies[rnd.int_range(0, copies.size)];
        tiles.remove(taken);
        return taken;
    }

    // Removes several copies of one type, or nothing at all if too few are left
    public ArrayList<Tile>? take(TileType type, int amount)
    {
        if (count(type) < amount)
            return null;

        ArrayList<Tile> taken = new ArrayList<Tile>();
        for (int i = 0; i < amount; i++)
            taken.add(take_one(type));
        return taken;
    }

    // Removes one copy of each type, or nothing at all if any type has run out
    public ArrayList<Tile>? take_each(TileType[] types)
    {
        foreach (TileType type in types)
            if (count(type) == 0)
                return null;

        ArrayList<Tile> taken = new ArrayList<Tile>();
        foreach (TileType type in types)
            taken.add(take_one(type));
        return taken;
    }

    // Removes random tiles of any type
    public ArrayList<Tile> take_random(int amount)
    {
        ArrayList<Tile> taken = new ArrayList<Tile>();
        for (int i = 0; i < amount && tiles.size > 0; i++)
            taken.add(tiles.remove_at(rnd.int_range(0, tiles.size)));
        return taken;
    }
}
