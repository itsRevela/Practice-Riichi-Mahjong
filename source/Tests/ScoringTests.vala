using Gee;

// Scoring engine tests. Expected values follow standard riichi rules
// (no kiriage mangan, double-wind pair = 4 fu, open tanyao allowed).

// 222m 678m 444p 99p + 55s, shanpon wait on 5s/9p, won on 5s.
private TestHand shanpon_hand(bool ron)
{
    return new TestHand() { concealed = "222678m444p99p55s", win = "5s", ron = ron, riichi = true };
}

// Chii 123m, then 45m waiting on 3m/6m; the called 123m must not count as a wait.
private TestHand called_meld_hand()
{
    TestHand hand = new TestHand() { concealed = "45m789p666z55z", win = "3m" };
    hand.calls.add(test_call(RoundStateCall.CallType.CHII, "123m", 3));
    return hand;
}

// Closed kan of 2p, plus 345m 678m 99p and a 45s ryanmen won on 6s.
private TestHand closed_kan_hand(bool ron)
{
    TestHand hand = new TestHand() { concealed = "345678m45s99p", win = "6s", ron = ron, riichi = ron };
    hand.calls.add(test_call(RoundStateCall.CallType.CLOSED_KAN, "2222p", 0));
    return hand;
}

// 34556m won on 4m reads as kanchan (35m) or ryanmen (56m); ryanmen gives pinfu.
private TestHand pinfu_or_kanchan_hand(bool dealer)
{
    return new TestHand()
    {
        concealed = "34556m234p678s99p",
        win = "4m",
        riichi = true,
        dealer = dealer,
        seat_wind = dealer ? Wind.EAST : Wind.WEST
    };
}

private TestHand pinfu_tsumo_hand(bool dealer)
{
    return new TestHand()
    {
        concealed = "34567m345p678s99p",
        win = "2m",
        ron = false,
        riichi = true,
        dealer = dealer,
        seat_wind = dealer ? Wind.EAST : Wind.WEST
    };
}

private void test_shanpon_ron_adds_no_wait_fu()
{
    expect_int("fu", 40, shanpon_hand(true).score().fu);
}

private void test_shanpon_ron_points()
{
    expect_int("ron points", 1300, shanpon_hand(true).score().ron_points);
}

private void test_ron_completed_triplet_is_not_concealed()
{
    expect_true("no san ankou on ron", !scoring_has_yaku(shanpon_hand(true).score(), YakuType.SAN_ANKOU));
}

private void test_tsumo_completed_triplet_is_concealed()
{
    expect_true("san ankou on tsumo", scoring_has_yaku(shanpon_hand(false).score(), YakuType.SAN_ANKOU));
}

private void test_called_meld_does_not_affect_wait()
{
    expect_int("fu", 30, called_meld_hand().score().fu);
}

private void test_closed_kan_keeps_menzen_tsumo()
{
    expect_true("menzen tsumo", scoring_has_yaku(closed_kan_hand(false).score(), YakuType.MENZEN_TSUMO));
}

private void test_closed_kan_tsumo_payments()
{
    Scoring score = closed_kan_hand(false).score();
    expect_int("non-dealer payment", 400, score.tsumo_points_lower);
    expect_int("dealer payment", 700, score.tsumo_points_higher);
}

private void test_closed_kan_keeps_closed_ron_fu()
{
    expect_int("fu", 50, closed_kan_hand(true).score().fu);
}

private void test_ambiguous_wait_prefers_pinfu()
{
    Scoring score = pinfu_or_kanchan_hand(false).score();
    expect_true("pinfu", scoring_has_yaku(score, YakuType.PINFU));
    expect_int("ron points", 2000, score.ron_points);
}

private void test_pinfu_tsumo_is_20_fu()
{
    expect_int("fu", 20, pinfu_tsumo_hand(false).score().fu);
}

private void test_non_dealer_tsumo_payments()
{
    Scoring score = pinfu_tsumo_hand(false).score();
    expect_int("non-dealer payment", 700, score.tsumo_points_lower);
    expect_int("dealer payment", 1300, score.tsumo_points_higher);
}

private void test_dealer_tsumo_payments()
{
    Scoring score = pinfu_tsumo_hand(true).score();
    expect_int("each player pays", 1300, score.tsumo_points_higher);
    expect_int("lower equals higher", 1300, score.tsumo_points_lower);
}

private void test_dealer_ron_payment()
{
    expect_int("ron points", 2900, pinfu_or_kanchan_hand(true).score().ron_points);
}

private void test_kanchan_wait_adds_two_fu()
{
    TestHand hand = new TestHand() { concealed = "46m234p345678s99p", win = "5m", riichi = true };
    expect_int("fu", 40, hand.score().fu);
}

private void test_penchan_wait_adds_two_fu()
{
    TestHand hand = new TestHand() { concealed = "12m234p345678s99p", win = "3m", riichi = true };
    expect_int("fu", 40, hand.score().fu);
}

private void test_tanki_wait_adds_two_fu()
{
    TestHand hand = new TestHand() { concealed = "123m234p345678s9p", win = "9p", riichi = true };
    expect_int("fu", 40, hand.score().fu);
}

private void test_open_hand_without_fu_is_30()
{
    TestHand hand = new TestHand() { concealed = "456p678s34s55m", win = "5s" };
    hand.calls.add(test_call(RoundStateCall.CallType.CHII, "234m", 3));
    Scoring score = hand.score();
    expect_int("fu", 30, score.fu);
    expect_int("ron points", 1000, score.ron_points);
}

private void test_chiitoitsu_is_25_fu()
{
    TestHand hand = new TestHand() { concealed = "1133m5577p99s22z4z", win = "4z", riichi = true };
    Scoring score = hand.score();
    expect_int("fu", 25, score.fu);
    expect_int("ron points", 3200, score.ron_points);
}

private void test_double_wind_pair_is_4_fu()
{
    TestHand hand = new TestHand()
    {
        concealed = "23m999p456789s11z",
        win = "4m",
        riichi = true,
        dealer = true,
        seat_wind = Wind.EAST,
        round_wind = Wind.EAST
    };
    expect_int("fu", 50, hand.score().fu);
}

private void test_fu_components_sum_to_raw_fu()
{
    Scoring score = closed_kan_hand(true).score();
    int sum = 0;
    foreach (FuComponent c in score.fu_components)
        sum += c.fu;
    expect_int("component sum", score.raw_fu, sum);
}

private void test_wait_pattern_is_reported()
{
    TestHand hand = new TestHand() { concealed = "46m234p345678s99p", win = "5m", riichi = true };
    expect_int("wait pattern", WaitPattern.KANCHAN, hand.score().wait_pattern);
}

private void test_open_minimum_is_itemised()
{
    TestHand hand = new TestHand() { concealed = "456p678s34s55m", win = "5s" };
    hand.calls.add(test_call(RoundStateCall.CallType.CHII, "234m", 3));
    Scoring score = hand.score();
    FuComponent last = score.fu_components[score.fu_components.size - 1];
    expect_int("last component", FuSource.OPEN_MINIMUM, last.source);
}

public void register_scoring_tests()
{
    Test.add_func("/scoring/fu_components_sum_to_raw_fu", test_fu_components_sum_to_raw_fu);
    Test.add_func("/scoring/wait_pattern_is_reported", test_wait_pattern_is_reported);
    Test.add_func("/scoring/open_minimum_is_itemised", test_open_minimum_is_itemised);
    Test.add_func("/scoring/shanpon_ron_adds_no_wait_fu", test_shanpon_ron_adds_no_wait_fu);
    Test.add_func("/scoring/shanpon_ron_points", test_shanpon_ron_points);
    Test.add_func("/scoring/ron_completed_triplet_is_not_concealed", test_ron_completed_triplet_is_not_concealed);
    Test.add_func("/scoring/tsumo_completed_triplet_is_concealed", test_tsumo_completed_triplet_is_concealed);
    Test.add_func("/scoring/called_meld_does_not_affect_wait", test_called_meld_does_not_affect_wait);
    Test.add_func("/scoring/closed_kan_keeps_menzen_tsumo", test_closed_kan_keeps_menzen_tsumo);
    Test.add_func("/scoring/closed_kan_tsumo_payments", test_closed_kan_tsumo_payments);
    Test.add_func("/scoring/closed_kan_keeps_closed_ron_fu", test_closed_kan_keeps_closed_ron_fu);
    Test.add_func("/scoring/ambiguous_wait_prefers_pinfu", test_ambiguous_wait_prefers_pinfu);
    Test.add_func("/scoring/pinfu_tsumo_is_20_fu", test_pinfu_tsumo_is_20_fu);
    Test.add_func("/scoring/non_dealer_tsumo_payments", test_non_dealer_tsumo_payments);
    Test.add_func("/scoring/dealer_tsumo_payments", test_dealer_tsumo_payments);
    Test.add_func("/scoring/dealer_ron_payment", test_dealer_ron_payment);
    Test.add_func("/scoring/kanchan_wait_adds_two_fu", test_kanchan_wait_adds_two_fu);
    Test.add_func("/scoring/penchan_wait_adds_two_fu", test_penchan_wait_adds_two_fu);
    Test.add_func("/scoring/tanki_wait_adds_two_fu", test_tanki_wait_adds_two_fu);
    Test.add_func("/scoring/open_hand_without_fu_is_30", test_open_hand_without_fu_is_30);
    Test.add_func("/scoring/chiitoitsu_is_25_fu", test_chiitoitsu_is_25_fu);
    Test.add_func("/scoring/double_wind_pair_is_4_fu", test_double_wind_pair_is_4_fu);
}
