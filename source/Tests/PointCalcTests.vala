using Engine;
using Gee;

// Tests for Point Calculation Practice: answer checking, hand generation and explanations.

private const int GENERATOR_SAMPLES = 400;

private PointCalcQuestion question_for(TestHand hand)
{
    Scoring scoring = hand.score();
    return new PointCalcQuestion(scoring.player, scoring.round, scoring);
}

private ArrayList<PointCalcQuestion> generate_samples()
{
    ArrayList<PointCalcQuestion> questions = new ArrayList<PointCalcQuestion>();
    PointCalcHandGenerator generator = new PointCalcHandGenerator(new RandomClass.seed(12345));

    for (int i = 0; i < GENERATOR_SAMPLES; i++)
    {
        PointCalcQuestion? question = generator.generate();
        if (question == null)
        {
            stderr.printf("FAIL %s: generator returned null on sample %d\n", Test.get_path(), i);
            Test.fail();
            break;
        }
        questions.add(question);
    }

    return questions;
}

// Every tile the question shows: concealed hand, winning tile, calls and indicators
private ArrayList<Tile> all_visible_tiles(PointCalcQuestion q)
{
    ArrayList<Tile> tiles = new ArrayList<Tile>();
    tiles.add_all(q.player.hand);
    tiles.add(q.round.win_tile);
    foreach (RoundStateCall call in q.player.calls)
        tiles.add_all(call.tiles);
    tiles.add_all(q.round.dora);
    tiles.add_all(q.round.ura_dora);
    return tiles;
}

private int kan_count(PointCalcQuestion q)
{
    int count = 0;
    foreach (RoundStateCall call in q.player.calls)
        if (call.tiles.size == 4)
            count++;
    return count;
}

// ---- Answers ----

private void test_parse_points_accepts_plain_number()
{
    expect_int("1300", 1300, PointCalcQuestion.parse_points("1300"));
}

private void test_parse_points_accepts_separators_and_spaces()
{
    expect_int(" 12,000 ", 12000, PointCalcQuestion.parse_points(" 12,000 "));
}

private void test_parse_points_rejects_empty()
{
    expect_int("empty", -1, PointCalcQuestion.parse_points(""));
}

private void test_parse_points_rejects_non_digits()
{
    expect_int("13OO", -1, PointCalcQuestion.parse_points("13OO"));
}

private void test_parse_points_rejects_negative()
{
    expect_int("-1000", -1, PointCalcQuestion.parse_points("-1000"));
}

private void test_parse_points_rejects_zero()
{
    expect_int("0", -1, PointCalcQuestion.parse_points("0"));
}

private void test_parse_points_rejects_decimal()
{
    expect_int("1300.5", -1, PointCalcQuestion.parse_points("1300.5"));
}

private void test_parse_points_rejects_too_large()
{
    expect_int("99999999", -1, PointCalcQuestion.parse_points("99999999"));
}

private void test_ron_answer_is_single_payment()
{
    PointCalcQuestion q = question_for(shanpon_hand(true));
    expect_string("answer", "1300", q.expected_text());
}

private void test_non_dealer_tsumo_answer_is_two_payments()
{
    PointCalcQuestion q = question_for(pinfu_tsumo_hand(false));
    expect_string("answer", "700 / 1300", q.expected_text());
}

private void test_dealer_tsumo_answer_is_all()
{
    PointCalcQuestion q = question_for(pinfu_tsumo_hand(true));
    expect_string("answer", "1300 all", q.expected_text());
}

private void test_non_dealer_tsumo_needs_both_payments()
{
    PointCalcQuestion q = question_for(pinfu_tsumo_hand(false));
    expect_true("wrong dealer payment is incorrect", !q.is_correct(700, 1200));
}

private void test_non_dealer_tsumo_correct_answer()
{
    PointCalcQuestion q = question_for(pinfu_tsumo_hand(false));
    expect_true("700 / 1300 is correct", q.is_correct(700, 1300));
}

private void test_ron_ignores_secondary_value()
{
    PointCalcQuestion q = question_for(shanpon_hand(true));
    expect_true("1300 is correct", q.is_correct(1300, 0));
}

// ---- Generator ----

private void test_generator_hands_have_yaku()
{
    foreach (PointCalcQuestion q in generate_samples())
        if (!q.scoring.valid || !q.scoring.has_valid_yaku())
        {
            expect_true("every generated hand is a valid win with a yaku", false);
            return;
        }
}

private void test_generator_uses_at_most_four_copies()
{
    foreach (PointCalcQuestion q in generate_samples())
    {
        int[] counts = new int[(int)TileType.CHUN + 1];
        HashSet<int> ids = new HashSet<int>();

        foreach (Tile tile in all_visible_tiles(q))
        {
            counts[(int)tile.tile_type]++;
            if (!ids.add(tile.ID))
            {
                expect_true("tile IDs are unique", false);
                return;
            }
        }

        foreach (int count in counts)
            if (count > 4)
            {
                expect_true("no tile type appears more than 4 times", false);
                return;
            }
    }
}

private void test_generator_hands_have_fourteen_tiles()
{
    foreach (PointCalcQuestion q in generate_samples())
    {
        // Each call replaces three concealed tiles, kans included
        int size = q.player.hand.size + 1 + 3 * q.player.calls.size;
        if (size != 14)
        {
            expect_int("effective hand size", 14, size);
            return;
        }
    }
}

private void test_generator_riichi_only_when_closed()
{
    foreach (PointCalcQuestion q in generate_samples())
        if (q.player.in_riichi && !TileRules.is_closed_hand(q.player.calls))
        {
            expect_true("riichi hands are closed", false);
            return;
        }
}

private void test_generator_one_indicator_per_kan()
{
    foreach (PointCalcQuestion q in generate_samples())
    {
        int expected = 1 + kan_count(q);
        if (q.round.dora.size != expected || q.round.ura_dora.size != expected)
        {
            expect_int("dora indicators", expected, q.round.dora.size);
            expect_int("ura dora indicators", expected, q.round.ura_dora.size);
            return;
        }
    }
}

private void test_generator_situational_yaku_are_consistent()
{
    foreach (PointCalcQuestion q in generate_samples())
    {
        bool ok = true;
        if (q.round.rinshan)
            ok = ok && !q.round.ron && kan_count(q) > 0 && !q.round.last_tile && !q.player.ippatsu;
        if (q.round.chankan)
            ok = ok && q.round.ron && !q.round.last_tile;
        if (q.player.ippatsu)
            ok = ok && q.player.in_riichi;

        if (!ok)
        {
            expect_true("situational flags are consistent", false);
            return;
        }
    }
}

private void test_generator_chankan_tile_is_unseen_elsewhere()
{
    foreach (PointCalcQuestion q in generate_samples())
    {
        if (!q.round.chankan)
            continue;

        int copies = 0;
        foreach (Tile tile in all_visible_tiles(q))
            if (tile.tile_type == q.round.win_tile.tile_type)
                copies++;

        if (copies != 1)
        {
            expect_int("visible copies of a robbed kan tile", 1, copies);
            return;
        }
    }
}

private void test_generator_covers_every_feature()
{
    bool open = false, kan = false, closed_kan = false, red_five = false, riichi = false;
    bool ron = false, tsumo = false, dealer = false, chiitoi = false, situational = false;

    foreach (PointCalcQuestion q in generate_samples())
    {
        open = open || !TileRules.is_closed_hand(q.player.calls);
        riichi = riichi || q.player.in_riichi;
        ron = ron || q.round.ron;
        tsumo = tsumo || !q.round.ron;
        dealer = dealer || q.player.dealer;
        chiitoi = chiitoi || q.scoring.hand.pairs.size == 7;
        situational = situational || q.round.rinshan || q.round.chankan || q.round.last_tile || q.player.ippatsu;

        foreach (RoundStateCall call in q.player.calls)
        {
            kan = kan || call.tiles.size == 4;
            closed_kan = closed_kan || call.call_type == RoundStateCall.CallType.CLOSED_KAN;
        }

        foreach (Tile tile in all_visible_tiles(q))
            red_five = red_five || tile.dora;
    }

    expect_true("open hands", open);
    expect_true("kans", kan);
    expect_true("closed kans", closed_kan);
    expect_true("red fives", red_five);
    expect_true("riichi", riichi);
    expect_true("ron", ron);
    expect_true("tsumo", tsumo);
    expect_true("dealer", dealer);
    expect_true("chiitoitsu", chiitoi);
    expect_true("situational yaku", situational);
}

// ---- Explanations ----

private ExplanationLine last_line(ArrayList<ExplanationLine> lines)
{
    return lines[lines.size - 1];
}

private bool any_label_contains(ArrayList<ExplanationLine> lines, string text)
{
    foreach (ExplanationLine l in lines)
        if (l.label.contains(text))
            return true;
    return false;
}

private void test_explanation_answer_line()
{
    PointCalcExplanation e = new PointCalcExplanation(question_for(pinfu_tsumo_hand(false)));
    expect_string("answer", "700 / 1300", last_line(e.points_lines).value);
}

private void test_explanation_fu_total()
{
    PointCalcExplanation e = new PointCalcExplanation(question_for(shanpon_hand(true)));
    ExplanationLine total = e.fu_lines[e.fu_lines.size - 1];
    expect_string("fu total", "40 fu", total.value);
}

private void test_explanation_names_zero_fu_wait()
{
    PointCalcExplanation e = new PointCalcExplanation(question_for(shanpon_hand(true)));
    expect_true("shanpon wait is listed", any_label_contains(e.fu_lines, "Shanpon"));
}

private void test_explanation_han_total()
{
    PointCalcExplanation e = new PointCalcExplanation(question_for(pinfu_tsumo_hand(false)));
    expect_string("han total", "3 han", last_line(e.han_lines).value);
}

private void test_explanation_names_yakuhai_tile()
{
    PointCalcExplanation e = new PointCalcExplanation(question_for(called_meld_hand()));
    expect_true("yakuhai names the dragon", any_label_contains(e.han_lines, "Green Dragon"));
}

private void test_explanation_shows_mangan_cap()
{
    // Riichi + tsumo + san ankou = 4 han at 40 fu, which exceeds the mangan cap
    PointCalcExplanation e = new PointCalcExplanation(question_for(shanpon_hand(false)));
    expect_true("mangan cap is explained", any_label_contains(e.points_lines, "Capped at mangan"));
}

private void test_explanation_for_every_generated_hand()
{
    foreach (PointCalcQuestion q in generate_samples())
    {
        PointCalcExplanation e = new PointCalcExplanation(q);
        if (last_line(e.points_lines).value != q.expected_text())
        {
            expect_string("explained answer", q.expected_text(), last_line(e.points_lines).value);
            return;
        }
    }
}

public void register_point_calc_tests()
{
    Test.add_func("/point_calc/parse_points_accepts_plain_number", test_parse_points_accepts_plain_number);
    Test.add_func("/point_calc/parse_points_accepts_separators_and_spaces", test_parse_points_accepts_separators_and_spaces);
    Test.add_func("/point_calc/parse_points_rejects_empty", test_parse_points_rejects_empty);
    Test.add_func("/point_calc/parse_points_rejects_non_digits", test_parse_points_rejects_non_digits);
    Test.add_func("/point_calc/parse_points_rejects_negative", test_parse_points_rejects_negative);
    Test.add_func("/point_calc/parse_points_rejects_zero", test_parse_points_rejects_zero);
    Test.add_func("/point_calc/parse_points_rejects_decimal", test_parse_points_rejects_decimal);
    Test.add_func("/point_calc/parse_points_rejects_too_large", test_parse_points_rejects_too_large);
    Test.add_func("/point_calc/ron_answer_is_single_payment", test_ron_answer_is_single_payment);
    Test.add_func("/point_calc/non_dealer_tsumo_answer_is_two_payments", test_non_dealer_tsumo_answer_is_two_payments);
    Test.add_func("/point_calc/dealer_tsumo_answer_is_all", test_dealer_tsumo_answer_is_all);
    Test.add_func("/point_calc/non_dealer_tsumo_needs_both_payments", test_non_dealer_tsumo_needs_both_payments);
    Test.add_func("/point_calc/non_dealer_tsumo_correct_answer", test_non_dealer_tsumo_correct_answer);
    Test.add_func("/point_calc/ron_ignores_secondary_value", test_ron_ignores_secondary_value);
    Test.add_func("/point_calc/generator_hands_have_yaku", test_generator_hands_have_yaku);
    Test.add_func("/point_calc/generator_uses_at_most_four_copies", test_generator_uses_at_most_four_copies);
    Test.add_func("/point_calc/generator_hands_have_fourteen_tiles", test_generator_hands_have_fourteen_tiles);
    Test.add_func("/point_calc/generator_riichi_only_when_closed", test_generator_riichi_only_when_closed);
    Test.add_func("/point_calc/generator_one_indicator_per_kan", test_generator_one_indicator_per_kan);
    Test.add_func("/point_calc/generator_situational_yaku_are_consistent", test_generator_situational_yaku_are_consistent);
    Test.add_func("/point_calc/generator_chankan_tile_is_unseen_elsewhere", test_generator_chankan_tile_is_unseen_elsewhere);
    Test.add_func("/point_calc/generator_covers_every_feature", test_generator_covers_every_feature);
    Test.add_func("/point_calc/explanation_answer_line", test_explanation_answer_line);
    Test.add_func("/point_calc/explanation_fu_total", test_explanation_fu_total);
    Test.add_func("/point_calc/explanation_names_zero_fu_wait", test_explanation_names_zero_fu_wait);
    Test.add_func("/point_calc/explanation_han_total", test_explanation_han_total);
    Test.add_func("/point_calc/explanation_names_yakuhai_tile", test_explanation_names_yakuhai_tile);
    Test.add_func("/point_calc/explanation_shows_mangan_cap", test_explanation_shows_mangan_cap);
    Test.add_func("/point_calc/explanation_for_every_generated_hand", test_explanation_for_every_generated_hand);
}
