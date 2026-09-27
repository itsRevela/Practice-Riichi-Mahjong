using Gee;

public enum ExplanationLineStyle
{
    HEADING,
    ITEM,
    TOTAL,
    NOTE
}

public class ExplanationLine : Object
{
    public ExplanationLine(string label, string value, ExplanationLineStyle style)
    {
        this.label = label;
        this.value = value;
        this.style = style;
    }

    public string label { get; private set; }
    public string value { get; private set; }
    public ExplanationLineStyle style { get; private set; }
}

// Explains how a Point Calculation Practice hand was scored, in three steps:
// count the han, count the fu, then turn han and fu into payments.
// Text is plain ASCII on purpose ("x" for multiply) so every font renders it.
public class PointCalcExplanation : Object
{
    private PointCalcQuestion question;
    private Scoring scoring;

    public PointCalcExplanation(PointCalcQuestion question)
    {
        this.question = question;
        scoring = question.scoring;

        han_lines = build_han_lines();
        fu_lines = build_fu_lines();
        points_lines = build_points_lines();
    }

    public ArrayList<ExplanationLine> han_lines { get; private set; }
    public ArrayList<ExplanationLine> fu_lines { get; private set; }
    public ArrayList<ExplanationLine> points_lines { get; private set; }

    private ArrayList<ExplanationLine> build_han_lines()
    {
        ArrayList<ExplanationLine> lines = new ArrayList<ExplanationLine>();
        lines.add(line("Han (yaku and dora)", "", ExplanationLineStyle.HEADING));

        foreach (Yaku yaku in scoring.yaku)
        {
            // Regular yaku don't add to a yakuman
            if (scoring.yakuman > 0 && yaku.yakuman == 0)
                continue;

            string value = yaku.yakuman > 0 ? yakuman_text(yaku.yakuman) : han_text(yaku.han);
            lines.add(line(yaku_label(yaku), value, ExplanationLineStyle.ITEM));
        }

        string total = scoring.yakuman > 0 ? yakuman_text(scoring.yakuman) : han_text(scoring.han);
        lines.add(line("Total", total, ExplanationLineStyle.TOTAL));

        return lines;
    }

    private ArrayList<ExplanationLine> build_fu_lines()
    {
        ArrayList<ExplanationLine> lines = new ArrayList<ExplanationLine>();
        lines.add(line("Fu", "", ExplanationLineStyle.HEADING));

        if (scoring.yakuman > 0)
        {
            lines.add(line("Not counted for yakuman", "", ExplanationLineStyle.NOTE));
            return lines;
        }

        FuSource[] order =
        {
            FuSource.BASE,
            FuSource.CHIITOI,
            FuSource.MELD,
            FuSource.WAIT,
            FuSource.DRAGON_PAIR,
            FuSource.ROUND_WIND_PAIR,
            FuSource.SEAT_WIND_PAIR,
            FuSource.TSUMO,
            FuSource.CLOSED_RON,
            FuSource.OPEN_MINIMUM
        };

        foreach (FuSource source in order)
        {
            bool found = false;

            foreach (FuComponent component in scoring.fu_components)
            {
                if (component.source != source)
                    continue;

                found = true;
                string value = (source == FuSource.BASE || source == FuSource.CHIITOI) ?
                    component.fu.to_string() : "+" + component.fu.to_string();
                lines.add(line(fu_label(component), value, ExplanationLineStyle.ITEM));
            }

            // Waits worth no fu are still worth naming
            if (source == FuSource.WAIT && !found && scoring.hand.pairs.size == 1 && scoring.wait_pattern != WaitPattern.NONE)
                lines.add(line(wait_label(scoring.wait_pattern), "+0", ExplanationLineStyle.ITEM));
        }

        if (has_yaku(YakuType.PINFU) && !scoring.ron)
            lines.add(line("Pinfu tsumo gets no tsumo fu", "", ExplanationLineStyle.NOTE));

        string total_label = scoring.raw_fu != scoring.fu ?
            "Total %d, round up to 10".printf(scoring.raw_fu) : "Total";
        lines.add(line(total_label, "%d fu".printf(scoring.fu), ExplanationLineStyle.TOTAL));

        if (scoring.han >= 5)
            lines.add(line("Fu doesn't matter at 5+ han", "", ExplanationLineStyle.NOTE));

        return lines;
    }

    private ArrayList<ExplanationLine> build_points_lines()
    {
        ArrayList<ExplanationLine> lines = new ArrayList<ExplanationLine>();
        lines.add(line("Points", "", ExplanationLineStyle.HEADING));

        int basic = scoring.basic_points;
        string? limit = limit_name(scoring.score_type);

        if (scoring.yakuman > 0)
            lines.add(line("Basic: 8000 x %d yakuman".printf(scoring.yakuman), basic.to_string(), ExplanationLineStyle.ITEM));
        else if (limit != null)
            lines.add(line("Basic: %d han = %s".printf(scoring.han, limit), basic.to_string(), ExplanationLineStyle.ITEM));
        else
        {
            // Below 5 han, so this can't overflow
            int uncapped = scoring.fu * (4 << scoring.han);
            lines.add(line("Basic: %d fu x 2^(2+%d)".printf(scoring.fu, scoring.han), uncapped.to_string(), ExplanationLineStyle.ITEM));

            if (uncapped > basic)
                lines.add(line("Capped at mangan", basic.to_string(), ExplanationLineStyle.ITEM));
        }

        switch (question.payment_style)
        {
        case PointCalcPaymentStyle.RON:
            if (scoring.dealer)
                lines.add(payment_line("Dealer ron", basic, 6, scoring.ron_points));
            else
                lines.add(payment_line("Non-dealer ron", basic, 4, scoring.ron_points));
            break;
        case PointCalcPaymentStyle.DEALER_TSUMO:
            lines.add(payment_line("Each player pays", basic, 2, scoring.tsumo_points_higher));
            break;
        case PointCalcPaymentStyle.NON_DEALER_TSUMO:
            lines.add(payment_line("Each non-dealer pays", basic, 1, scoring.tsumo_points_lower));
            lines.add(payment_line("Dealer pays", basic, 2, scoring.tsumo_points_higher));
            break;
        }

        lines.add(line("Payments round up to the next 100", "", ExplanationLineStyle.NOTE));

        if (question.payment_style != PointCalcPaymentStyle.RON)
            lines.add(line("Total collected", scoring.total_points.to_string(), ExplanationLineStyle.ITEM));

        lines.add(line("Answer", question.expected_text(), ExplanationLineStyle.TOTAL));

        return lines;
    }

    private static ExplanationLine payment_line(string who, int basic, int multiplier, int rounded)
    {
        string label = "%s: %d x %d = %d".printf(who, basic, multiplier, basic * multiplier);
        return line(label, rounded.to_string(), ExplanationLineStyle.ITEM);
    }

    private static ExplanationLine line(string label, string value, ExplanationLineStyle style)
    {
        return new ExplanationLine(label, value, style);
    }

    private bool has_yaku(YakuType type)
    {
        foreach (Yaku yaku in scoring.yaku)
            if (yaku.yaku_type == type)
                return true;
        return false;
    }

    private string yaku_label(Yaku yaku)
    {
        switch (yaku.yaku_type)
        {
        case YakuType.YAKUHAI:
            return "Yakuhai: " + yakuhai_detail();
        case YakuType.DORA:
            return "Dora (" + dora_names(scoring.round.dora) + ")";
        case YakuType.URA_DORA:
            return "Ura dora (" + dora_names(scoring.round.ura_dora) + ")";
        default:
            break;
        }

        string name = yaku_name(yaku.yaku_type);
        if (is_open_reduced(yaku.yaku_type) && !TileRules.is_closed_hand(scoring.player.calls))
            name += " (open, -1)";
        return name;
    }

    // Which honor triplets made the yakuhai, e.g. "White Dragon, East (seat + round)"
    private string yakuhai_detail()
    {
        StringBuilder sb = new StringBuilder();

        foreach (TileMeld meld in scoring.hand.melds)
        {
            Tile tile = meld.tile_1;
            if (!meld.is_triplet || !tile.is_honor_tile())
                continue;

            string part;
            bool seat = tile.is_wind(scoring.player.wind);
            bool round = tile.is_wind(scoring.round.round_wind);

            if (tile.is_dragon_tile())
                part = tile_name(tile.tile_type);
            else if (seat && round)
                part = tile_name(tile.tile_type) + " (seat + round)";
            else if (seat)
                part = tile_name(tile.tile_type) + " (seat)";
            else if (round)
                part = tile_name(tile.tile_type) + " (round)";
            else
                continue;

            if (sb.len > 0)
                sb.append(", ");
            sb.append(part);
        }

        return sb.str;
    }

    // The tiles the indicators point to, e.g. "5-Man, Red Dragon"
    private static string dora_names(ArrayList<Tile> indicators)
    {
        ArrayList<TileType> seen = new ArrayList<TileType>();
        StringBuilder sb = new StringBuilder();

        foreach (Tile indicator in indicators)
        {
            TileType dora = indicator.dora_indicator();
            if (seen.contains(dora))
                continue;
            seen.add(dora);

            if (sb.len > 0)
                sb.append(", ");
            sb.append(tile_name(dora));
        }

        return sb.str;
    }

    private string fu_label(FuComponent component)
    {
        switch (component.source)
        {
        case FuSource.BASE:
            return "Base fu";
        case FuSource.CHIITOI:
            return "Seven pairs (always 25)";
        case FuSource.MELD:
            return meld_label(component.meld);
        case FuSource.WAIT:
            return wait_label(scoring.wait_pattern);
        case FuSource.DRAGON_PAIR:
            return "Dragon pair: " + tile_name(scoring.hand.pairs[0].tile_1.tile_type);
        case FuSource.ROUND_WIND_PAIR:
            return "Round wind pair: " + tile_name(scoring.hand.pairs[0].tile_1.tile_type);
        case FuSource.SEAT_WIND_PAIR:
            return "Seat wind pair: " + tile_name(scoring.hand.pairs[0].tile_1.tile_type);
        case FuSource.TSUMO:
            return "Tsumo (self-draw)";
        case FuSource.CLOSED_RON:
            return "Closed hand won by ron";
        case FuSource.OPEN_MINIMUM:
            return "Open hand minimum is 30";
        default:
            return component.source.to_string();
        }
    }

    // e.g. "Closed kan: 9-Pin (terminal)"
    private static string meld_label(TileMeld meld)
    {
        Tile tile = meld.tile_1;
        string kind = (meld.is_closed ? "Closed " : "Open ") + (meld.is_kan ? "kan" : "triplet");
        string label = kind + ": " + tile_name(tile.tile_type);

        if (tile.is_honor_tile())
            label += " (honor)";
        else if (tile.is_terminal_tile())
            label += " (terminal)";

        return label;
    }

    public static string wait_label(WaitPattern wait)
    {
        switch (wait)
        {
        case WaitPattern.RYANMEN:
            return "Ryanmen wait (two-sided)";
        case WaitPattern.KANCHAN:
            return "Kanchan wait (middle)";
        case WaitPattern.PENCHAN:
            return "Penchan wait (edge)";
        case WaitPattern.SHANPON:
            return "Shanpon wait (two pairs)";
        case WaitPattern.TANKI:
            return "Tanki wait (single tile)";
        case WaitPattern.NONE:
        default:
            return "Wait";
        }
    }

    // Yaku that are worth one han less in an open hand
    private static bool is_open_reduced(YakuType type)
    {
        return type == YakuType.SANSHOKU_DOUJUN ||
               type == YakuType.ITTSUU ||
               type == YakuType.CHANTA ||
               type == YakuType.JUNCHAN ||
               type == YakuType.HONITSU ||
               type == YakuType.CHINITSU;
    }

    private static string? limit_name(Scoring.ScoreType type)
    {
        switch (type)
        {
        case Scoring.ScoreType.MANGAN:
            return "Mangan";
        case Scoring.ScoreType.HANEMAN:
            return "Haneman";
        case Scoring.ScoreType.BAIMAN:
            return "Baiman";
        case Scoring.ScoreType.SANBAIMAN:
            return "Sanbaiman";
        case Scoring.ScoreType.KAZOE_YAKUMAN:
            return "Kazoe Yakuman";
        default:
            return null;
        }
    }

    private static string han_text(int han)
    {
        return "%d han".printf(han);
    }

    private static string yakuman_text(int count)
    {
        if (count == 1)
            return "Yakuman";
        if (count == 2)
            return "Double Yakuman";
        return "%dx Yakuman".printf(count);
    }

    public static string tile_name(TileType type)
    {
        int t = (int)type;

        if (t >= (int)TileType.MAN1 && t <= (int)TileType.MAN9)
            return "%d-Man".printf(t - (int)TileType.MAN1 + 1);
        if (t >= (int)TileType.PIN1 && t <= (int)TileType.PIN9)
            return "%d-Pin".printf(t - (int)TileType.PIN1 + 1);
        if (t >= (int)TileType.SOU1 && t <= (int)TileType.SOU9)
            return "%d-Sou".printf(t - (int)TileType.SOU1 + 1);

        switch (type)
        {
        case TileType.TON:
            return "East";
        case TileType.NAN:
            return "South";
        case TileType.SHAA:
            return "West";
        case TileType.PEI:
            return "North";
        case TileType.HAKU:
            return "White Dragon";
        case TileType.HATSU:
            return "Green Dragon";
        case TileType.CHUN:
            return "Red Dragon";
        default:
            return "Blank";
        }
    }

    public static string yaku_name(YakuType type)
    {
        switch (type)
        {
        case YakuType.MENZEN_TSUMO:
            return "Menzen tsumo (closed self-draw)";
        case YakuType.RIICHI:
            return "Riichi";
        case YakuType.OPEN_RIICHI:
            return "Open riichi";
        case YakuType.IPPATSU:
            return "Ippatsu (win within a turn of riichi)";
        case YakuType.DOUBLE_RIICHI:
            return "Double riichi";
        case YakuType.HAITEI_RAOYUE:
            return "Haitei (self-draw on the last tile)";
        case YakuType.HOUTEI_RAOYUI:
            return "Houtei (ron on the last discard)";
        case YakuType.RINSHAN_KAIHOU:
            return "Rinshan (win on a kan replacement)";
        case YakuType.CHANKAN:
            return "Chankan (robbing a kan)";
        case YakuType.NAGASHI_MANGAN:
            return "Nagashi mangan";
        case YakuType.PINFU:
            return "Pinfu (no-points hand)";
        case YakuType.TANYAO:
            return "Tanyao (all simples, 2-8)";
        case YakuType.IIPEIKOU:
            return "Iipeikou (two identical sequences)";
        case YakuType.YAKUHAI:
            return "Yakuhai (value triplets)";
        case YakuType.SANSHOKU_DOUJUN:
            return "Sanshoku (same sequence, 3 suits)";
        case YakuType.ITTSUU:
            return "Ittsuu (straight 1-9)";
        case YakuType.CHANTA:
            return "Chanta (terminal/honor in each set)";
        case YakuType.HONROUTOU:
            return "Honroutou (only terminals and honors)";
        case YakuType.TOITOI:
            return "Toitoi (all triplets)";
        case YakuType.SAN_ANKOU:
            return "San ankou (3 concealed triplets)";
        case YakuType.SAN_KANTSU:
            return "San kantsu (3 kans)";
        case YakuType.SANSHOKU_DOUKOU:
            return "Sanshoku doukou (same triplet, 3 suits)";
        case YakuType.CHIITOI:
            return "Chiitoitsu (seven pairs)";
        case YakuType.SHOU_SANGEN:
            return "Shousangen (little three dragons)";
        case YakuType.HONITSU:
            return "Honitsu (half flush)";
        case YakuType.JUNCHAN:
            return "Junchan (terminal in each set)";
        case YakuType.RYANPEIKOU:
            return "Ryanpeikou (two iipeikou)";
        case YakuType.CHINITSU:
            return "Chinitsu (full flush)";
        case YakuType.TENHOU:
            return "Tenhou (dealer's first draw)";
        case YakuType.CHIIHOU:
            return "Chiihou (first draw)";
        case YakuType.RENHOU:
            return "Renhou (ron before first draw)";
        case YakuType.KOKUSHI_MUSOU:
            return "Kokushi musou (thirteen orphans)";
        case YakuType.DAI_SANGEN:
            return "Daisangen (big three dragons)";
        case YakuType.SHOU_SUUSHII:
            return "Shousuushii (little four winds)";
        case YakuType.DAI_SUUSHII:
            return "Daisuushii (big four winds)";
        case YakuType.CHUUREN_POUTOU:
            return "Chuuren poutou (nine gates)";
        case YakuType.SUU_ANKOU:
            return "Suu ankou (4 concealed triplets)";
        case YakuType.RYUUIISOU:
            return "Ryuuiisou (all green)";
        case YakuType.SUU_KANTSU:
            return "Suu kantsu (4 kans)";
        case YakuType.TSUU_IISOU:
            return "Tsuuiisou (all honors)";
        case YakuType.CHINROUTOU:
            return "Chinroutou (all terminals)";
        case YakuType.DORA:
            return "Dora";
        case YakuType.URA_DORA:
            return "Ura dora";
        case YakuType.AKA_DORA:
            return "Red fives (aka dora)";
        default:
            return type.to_string();
        }
    }
}
