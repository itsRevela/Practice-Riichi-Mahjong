using Gee;

// How a win is paid, which decides how many numbers the player must enter.
// Mirrors how scores are announced at the table.
public enum PointCalcPaymentStyle
{
    RON,             // One payment from the discarder, e.g. "3900"
    DEALER_TSUMO,    // Every player pays the same, e.g. "2000 all"
    NON_DEALER_TSUMO // Non-dealers pay less than the dealer, e.g. "1000 / 2000"
}

// One round of Point Calculation Practice: a winning hand, its context and its score
public class PointCalcQuestion : Object
{
    // Anything above this is not a real payment, so treat it as a typo
    public const int MAX_POINTS = 1000000;

    public PointCalcQuestion(PlayerStateContext player, RoundStateContext round, Scoring scoring)
    {
        this.player = player;
        this.round = round;
        this.scoring = scoring;
    }

    public PlayerStateContext player { get; private set; }
    public RoundStateContext round { get; private set; }
    public Scoring scoring { get; private set; }

    public PointCalcPaymentStyle payment_style
    {
        get
        {
            if (scoring.ron)
                return PointCalcPaymentStyle.RON;
            return scoring.dealer ? PointCalcPaymentStyle.DEALER_TSUMO : PointCalcPaymentStyle.NON_DEALER_TSUMO;
        }
    }

    // Ron payment, the "all" payment for a dealer tsumo, or what each non-dealer pays on a non-dealer tsumo
    public int expected_primary
    {
        get
        {
            switch (payment_style)
            {
            case PointCalcPaymentStyle.RON:
                return scoring.ron_points;
            case PointCalcPaymentStyle.DEALER_TSUMO:
                return scoring.tsumo_points_higher;
            case PointCalcPaymentStyle.NON_DEALER_TSUMO:
            default:
                return scoring.tsumo_points_lower;
            }
        }
    }

    // What the dealer pays on a non-dealer tsumo; 0 for the other payment styles
    public int expected_secondary
    {
        get { return payment_style == PointCalcPaymentStyle.NON_DEALER_TSUMO ? scoring.tsumo_points_higher : 0; }
    }

    public bool is_correct(int primary, int secondary)
    {
        if (primary != expected_primary)
            return false;
        return payment_style != PointCalcPaymentStyle.NON_DEALER_TSUMO || secondary == expected_secondary;
    }

    public string expected_text()
    {
        return format_answer(expected_primary, expected_secondary);
    }

    public string format_answer(int primary, int secondary)
    {
        switch (payment_style)
        {
        case PointCalcPaymentStyle.DEALER_TSUMO:
            return "%d all".printf(primary);
        case PointCalcPaymentStyle.NON_DEALER_TSUMO:
            return "%d / %d".printf(primary, secondary);
        case PointCalcPaymentStyle.RON:
        default:
            return primary.to_string();
        }
    }

    // Parses a typed point value. Spaces and thousands separators are allowed ("1,300").
    // Returns -1 when the text is not a positive whole number of at most MAX_POINTS.
    public static int parse_points(string text)
    {
        StringBuilder digits = new StringBuilder();

        for (int i = 0; i < text.length; i++)
        {
            char c = text[i];

            if (c >= '0' && c <= '9')
                digits.append_c(c);
            else if (c != ',' && c != ' ')
                return -1;
        }

        // Longer than MAX_POINTS can ever be; also keeps int.parse from overflowing
        if (digits.len == 0 || digits.len > 7)
            return -1;

        int value = int.parse(digits.str);
        if (value <= 0 || value > MAX_POINTS)
            return -1;

        return value;
    }
}
