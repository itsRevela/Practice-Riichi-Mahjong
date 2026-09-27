using Engine;
using Gee;

// Point Calculation Practice: an endless series of random winning hands.
// The player enters what each hand pays. The full calculation is shown after
// every answer, and (with hints on) on demand before answering.
class PointCalcPracticeView : MenuSubView
{
    private enum Phase
    {
        SETUP,
        QUESTION,
        FEEDBACK
    }

    // Vertical layout, in pixels below the title
    private const float CONTEXT_Y = 8;
    private const float SITUATION_Y = 40;
    private const float DORA_LABEL_Y = 74;
    private const float DORA_Y = 96;
    private const float DORA_WIDTH = 560;
    private const float DORA_HEIGHT = 70;
    private const float DORA_X = 300;
    private const float HAND_Y = 172;
    private const float HAND_HEIGHT = 180;
    private const float CAPTION_Y = 356;
    private const float AREA_Y = 392; // Answer inputs, hint and feedback all start here

    private const float HAND_MAX_WIDTH = 1300;
    private const float PANEL_MAX_WIDTH = 1500;
    private const float SIDE_MARGIN = 50;
    private const float AREA_BOTTOM_GAP = 10;
    private const float INPUT_WIDTH = 240;
    private const float INPUT_HEIGHT = 40;
    private const float INPUT_ROW_HEIGHT = 56;

    private const string[] HINT_CHOICES = { "Off", "On" };
    private const int HINTS_ON = 1;

    private Phase phase = Phase.SETUP;
    private bool hints_enabled = true;
    private PointCalcHandGenerator generator;
    private PointCalcQuestion? question = null;

    private View2D? setup_container = null;
    private OptionItemControl? hints_option = null;

    private View2D? round_container = null;
    private View2D? answer_container = null;
    private View2D? hint_popup = null;
    private ScoringHandView? hand_view = null;
    private PointCalcAnswerInput? primary_input = null;
    private PointCalcAnswerInput? secondary_input = null;
    private LabelControl? input_error_label = null;
    private ArrayList<PointCalcCalculationView> calculation_views = new ArrayList<PointCalcCalculationView>();

    private MenuTextButton? start_button = null;
    private MenuTextButton? hint_button = null;
    private MenuTextButton? hide_hint_button = null;
    private MenuTextButton? submit_button = null;
    private MenuTextButton? next_button = null;
    private MenuTextButton? back_button = null;
    private MenuTextButton? main_menu_button = null;

    public PointCalcPracticeView()
    {
        generator = new PointCalcHandGenerator(new RandomClass());
    }

    protected override string get_name()
    {
        return "Point Calculation Practice";
    }

    protected override ArrayList<MenuTextButton>? get_menu_buttons()
    {
        // Each phase shows a subset of these; the bar re-centres the visible ones
        ArrayList<MenuTextButton> buttons = new ArrayList<MenuTextButton>();

        start_button = add_menu_button(buttons, "Start");
        start_button.clicked.connect(start_clicked);

        hint_button = add_menu_button(buttons, "Hint");
        hint_button.clicked.connect(hint_clicked);

        hide_hint_button = add_menu_button(buttons, "Hide Hint");
        hide_hint_button.clicked.connect(hide_hint_clicked);

        submit_button = add_menu_button(buttons, "Submit");
        submit_button.clicked.connect(submit_clicked);

        next_button = add_menu_button(buttons, "Next Hand");
        next_button.clicked.connect(next_clicked);

        back_button = add_menu_button(buttons, "Back");
        back_button.clicked.connect(do_back);

        main_menu_button = add_menu_button(buttons, "Main Menu");
        main_menu_button.clicked.connect(do_back);

        return buttons;
    }

    private static MenuTextButton add_menu_button(ArrayList<MenuTextButton> buttons, string text)
    {
        MenuTextButton button = new MenuTextButton("MenuButton", text);
        buttons.add(button);
        return button;
    }

    protected override void load_finished()
    {
        // Hide the main-menu rotating tile / banner so they don't compete with the hand
        MainWindow? mw = window as MainWindow;
        if (mw != null)
            mw.set_main_menu_decoration_visible(false);

        build_setup_ui();
        update_buttons();
    }

    public override void removed()
    {
        MainWindow? mw = window as MainWindow;
        if (mw != null)
            mw.set_main_menu_decoration_visible(true);
    }

    protected override void resized()
    {
        if (hand_view != null)
            hand_view.size = Size2(hand_width(), HAND_HEIGHT);

        foreach (PointCalcCalculationView view in calculation_views)
            view.size = Size2(panel_width(), view.size.height);
    }

    private void update_buttons()
    {
        bool question_phase = phase == Phase.QUESTION;
        bool hint_open = hint_popup != null;

        start_button.visible = phase == Phase.SETUP;
        back_button.visible = phase == Phase.SETUP;
        hint_button.visible = question_phase && hints_enabled && !hint_open;
        hide_hint_button.visible = question_phase && hint_open;
        // The answer boxes are hidden under the hint, so answering waits until it's closed
        submit_button.visible = question_phase && !hint_open;
        next_button.visible = phase == Phase.FEEDBACK;
        main_menu_button.visible = phase != Phase.SETUP;
    }

    // ---- Setup ----

    private void build_setup_ui()
    {
        setup_container = new View2D();
        add_child(setup_container);
        setup_container.resize_style = ResizeStyle.RELATIVE;

        float y = top_offset + 40;
        y = add_label(setup_container, "Each round deals a random winning hand, along with its round context.", 24, y, 36, Color.white());
        y = add_label(setup_container, "Work out what the hand is worth and enter the payment as it's announced at the table:", 24, y, 44, Color.white());
        y = add_label(setup_container, "Ron: 3900        Dealer tsumo: 2000 all        Non-dealer tsumo: 1000 / 2000", 22, y, 70, Color(0.7f, 0.85f, 1.0f, 1));

        hints_option = new OptionItemControl(true, "Hints", HINT_CHOICES, hints_enabled ? HINTS_ON : 0);
        setup_container.add_child(hints_option);
        hints_option.size = Size2(600, 55);
        hints_option.outer_anchor = Vec2(0.5f, 1);
        hints_option.inner_anchor = Vec2(0.5f, 1);
        hints_option.position = Vec2(0, -y);
        y += 70;

        add_label(setup_container, "With hints on, a Hint button can show the full calculation before you answer.", 18, y, 30, Color(0.75f, 0.75f, 0.75f, 1));
    }

    private void start_clicked()
    {
        if (phase != Phase.SETUP)
            return;

        hints_enabled = hints_option.index == HINTS_ON;
        remove_child(setup_container);
        setup_container = null;
        hints_option = null;

        next_round();
    }

    // ---- Question ----

    private void next_clicked()
    {
        if (phase == Phase.FEEDBACK)
            next_round();
    }

    private void next_round()
    {
        clear_round();

        round_container = new View2D();
        add_child(round_container);
        round_container.resize_style = ResizeStyle.RELATIVE;

        question = generator.generate();
        if (question == null)
        {
            // The generator already logged why; let the player retry
            add_label(round_container, "Could not deal a hand. Press Next Hand to try again.", 26, top_offset + AREA_Y, 40, Color(1, 0.45f, 0.45f, 1));
            phase = Phase.FEEDBACK;
            update_buttons();
            return;
        }

        phase = Phase.QUESTION;
        build_hand_display();
        build_answer_inputs();
        update_buttons();
    }

    private void clear_round()
    {
        if (round_container != null)
            remove_child(round_container);

        round_container = null;
        answer_container = null;
        hint_popup = null;
        hand_view = null;
        primary_input = null;
        secondary_input = null;
        input_error_label = null;
        calculation_views.clear();
    }

    private void build_hand_display()
    {
        PlayerStateContext player = question.player;
        RoundStateContext round = question.round;

        string context = "Round wind: %s %s    |    Seat wind: %s %s    |    %s    |    %s".printf(
            WIND_TO_STRING(round.round_wind), WIND_TO_KANJI(round.round_wind),
            WIND_TO_STRING(player.wind), WIND_TO_KANJI(player.wind),
            player.dealer ? "Dealer" : "Non-dealer",
            round.ron ? "Ron (won on a discard)" : "Tsumo (self-draw)");
        add_label(round_container, context, 24, top_offset + CONTEXT_Y, 0, Color.white());
        add_label(round_container, situation_text(), 20, top_offset + SITUATION_Y, 0, Color(1, 0.85f, 0.3f, 1));

        // Ura dora only counts (and is only revealed) for a riichi hand
        ArrayList<Tile> ura = round.ura_dora;
        string ura_title = "Ura dora indicators";
        if (!player.in_riichi)
        {
            ura = new ArrayList<Tile>();
            for (int i = 0; i < round.ura_dora.size; i++)
                ura.add(new Tile(-1, TileType.BLANK, false)); // Drawn face down
            ura_title += " (hidden: no riichi)";
        }

        add_dora_view("Dora indicators", round.dora, -DORA_X);
        add_dora_view(ura_title, ura, DORA_X);

        hand_view = new ScoringHandView(null, question.scoring);
        round_container.add_child(hand_view);
        hand_view.outer_anchor = Vec2(0.5f, 1);
        hand_view.inner_anchor = Vec2(0.5f, 1);
        hand_view.size = Size2(hand_width(), HAND_HEIGHT);
        hand_view.position = Vec2(0, -(top_offset + HAND_Y));

        Tile win = round.win_tile;
        string caption = "Winning tile (set apart from the hand): " + PointCalcExplanation.tile_name(win.tile_type) + (win.dora ? " (red five)" : "");
        add_label(round_container, caption, 18, top_offset + CAPTION_Y, 0, Color(0.85f, 0.85f, 0.85f, 1));
    }

    private void add_dora_view(string title, ArrayList<Tile> tiles, float x)
    {
        LabelControl label = new LabelControl();
        round_container.add_child(label);
        label.text = title;
        label.font_size = 18;
        label.outer_anchor = Vec2(0.5f, 1);
        label.inner_anchor = Vec2(0.5f, 1);
        label.position = Vec2(x, -(top_offset + DORA_LABEL_Y));

        ScoringDoraView view = new ScoringDoraView(tiles, 0, 0);
        round_container.add_child(view);
        view.outer_anchor = Vec2(0.5f, 1);
        view.inner_anchor = Vec2(0.5f, 1);
        view.size = Size2(DORA_WIDTH, DORA_HEIGHT);
        view.position = Vec2(x, -(top_offset + DORA_Y));
    }

    // Riichi status plus any situational yaku, which can't be seen from the tiles
    private string situation_text()
    {
        ArrayList<string> parts = new ArrayList<string>();
        parts.add(question.player.in_riichi ? "Riichi declared" : "No riichi");

        if (question.player.ippatsu)
            parts.add(PointCalcExplanation.yaku_name(YakuType.IPPATSU));
        if (question.round.last_tile)
            parts.add(PointCalcExplanation.yaku_name(question.round.ron ? YakuType.HOUTEI_RAOYUI : YakuType.HAITEI_RAOYUE));
        if (question.round.rinshan)
            parts.add(PointCalcExplanation.yaku_name(YakuType.RINSHAN_KAIHOU));
        if (question.round.chankan)
            parts.add(PointCalcExplanation.yaku_name(YakuType.CHANKAN));

        return string.joinv("    |    ", parts.to_array());
    }

    private void build_answer_inputs()
    {
        answer_container = new View2D();
        round_container.add_child(answer_container);
        answer_container.resize_style = ResizeStyle.RELATIVE;

        float y = add_label(answer_container, "How many points is this hand worth?", 28, top_offset + AREA_Y, 50, Color.white());

        switch (question.payment_style)
        {
        case PointCalcPaymentStyle.RON:
            primary_input = add_input_row("Ron payment:", "points", y);
            y += INPUT_ROW_HEIGHT;
            break;
        case PointCalcPaymentStyle.DEALER_TSUMO:
            primary_input = add_input_row("Each player pays:", "all", y);
            y += INPUT_ROW_HEIGHT;
            break;
        case PointCalcPaymentStyle.NON_DEALER_TSUMO:
            primary_input = add_input_row("Each non-dealer pays:", "", y);
            y += INPUT_ROW_HEIGHT;
            secondary_input = add_input_row("Dealer pays:", "", y);
            y += INPUT_ROW_HEIGHT;
            break;
        }

        input_error_label = new LabelControl();
        answer_container.add_child(input_error_label);
        input_error_label.font_size = 20;
        input_error_label.color = Color(1, 0.45f, 0.45f, 1);
        input_error_label.outer_anchor = Vec2(0.5f, 1);
        input_error_label.inner_anchor = Vec2(0.5f, 1);
        input_error_label.position = Vec2(0, -y);
        input_error_label.text = "";
        y += 30;

        add_label(answer_container, "Click a box to type, then press Enter or Submit.", 16, y, 0, Color(0.7f, 0.7f, 0.7f, 1));
    }

    private PointCalcAnswerInput add_input_row(string title, string suffix, float y)
    {
        float center_y = -(y + INPUT_HEIGHT / 2);

        LabelControl label = new LabelControl();
        answer_container.add_child(label);
        label.text = title;
        label.font_size = 22;
        label.outer_anchor = Vec2(0.5f, 1);
        label.inner_anchor = Vec2(1, 0.5f);
        label.position = Vec2(-(INPUT_WIDTH / 2 + 16), center_y);

        // The text box draws its background at its size when added, so size it first
        PointCalcAnswerInput input = new PointCalcAnswerInput();
        input.size = Size2(INPUT_WIDTH, INPUT_HEIGHT);
        answer_container.add_child(input);
        input.outer_anchor = Vec2(0.5f, 1);
        input.inner_anchor = Vec2(0.5f, 0.5f);
        input.position = Vec2(0, center_y);
        input.submitted.connect(submit_clicked);

        if (suffix != "")
        {
            LabelControl suffix_label = new LabelControl();
            answer_container.add_child(suffix_label);
            suffix_label.text = suffix;
            suffix_label.font_size = 22;
            suffix_label.outer_anchor = Vec2(0.5f, 1);
            suffix_label.inner_anchor = Vec2(0, 0.5f);
            suffix_label.position = Vec2(INPUT_WIDTH / 2 + 16, center_y);
        }

        return input;
    }

    private void submit_clicked()
    {
        // Feedback replaces the answer area but not the hint popup, so never submit while it's open
        if (phase != Phase.QUESTION || primary_input == null || hint_popup != null)
            return;

        bool two_payments = question.payment_style == PointCalcPaymentStyle.NON_DEALER_TSUMO;
        int primary = PointCalcQuestion.parse_points(primary_input.text);
        int secondary = two_payments ? PointCalcQuestion.parse_points(secondary_input.text) : 0;

        if (primary < 0 || secondary < 0)
        {
            input_error_label.text = two_payments ?
                "Enter both payments as whole numbers, e.g. 1000 and 2000." :
                "Enter the payment as a whole number, e.g. 3900.";
            return;
        }

        show_feedback(primary, secondary);
    }

    // ---- Hint ----

    private void hint_clicked()
    {
        if (phase != Phase.QUESTION || !hints_enabled || hint_popup != null)
            return;

        // Hide the inputs so typing can't reach a box that's covered up
        answer_container.visible = false;

        hint_popup = new View2D();
        round_container.add_child(hint_popup);
        hint_popup.resize_style = ResizeStyle.RELATIVE;

        // A selectable backdrop swallows clicks meant for whatever is underneath
        RectangleControl backdrop = new RectangleControl();
        hint_popup.add_child(backdrop);
        backdrop.resize_style = ResizeStyle.ABSOLUTE;
        backdrop.size = Size2(panel_width() + 40, area_height() + 10);
        backdrop.color = Color(0, 0, 0, 0.75f);
        backdrop.selectable = true;
        backdrop.cursor_type = CursorType.NORMAL;
        backdrop.outer_anchor = Vec2(0.5f, 1);
        backdrop.inner_anchor = Vec2(0.5f, 1);
        backdrop.position = Vec2(0, -(top_offset + AREA_Y - 10));

        float y = add_label(hint_popup, "Hint: how this hand is scored", 26, top_offset + AREA_Y, 42, Color(1, 0.95f, 0.4f, 1));
        add_calculation_view(hint_popup, y);

        update_buttons();
    }

    private void hide_hint_clicked()
    {
        if (hint_popup == null)
            return;

        round_container.remove_child(hint_popup);
        hint_popup = null;
        calculation_views.clear();
        answer_container.visible = true;

        update_buttons();
    }

    // ---- Feedback ----

    private void show_feedback(int primary, int secondary)
    {
        phase = Phase.FEEDBACK;
        round_container.remove_child(answer_container);
        answer_container = null;
        primary_input = null;
        secondary_input = null;
        input_error_label = null;

        bool correct = question.is_correct(primary, secondary);
        float y = top_offset + AREA_Y;

        y = add_label(round_container, correct ? "Correct!" : "Not quite", 34, y, 44,
            correct ? Color(0.45f, 1, 0.45f, 1) : Color(1, 0.45f, 0.45f, 1));
        y = add_label(round_container,
            "Your answer: %s        Correct answer: %s".printf(question.format_answer(primary, secondary), question.expected_text()),
            22, y, 36, Color.white());

        add_calculation_view(round_container, y);
        update_buttons();
    }

    // ---- Helpers ----

    private void add_calculation_view(Container parent, float y)
    {
        PointCalcCalculationView view = new PointCalcCalculationView(new PointCalcExplanation(question));
        parent.add_child(view);
        view.outer_anchor = Vec2(0.5f, 1);
        view.inner_anchor = Vec2(0.5f, 1);
        view.size = Size2(panel_width(), Math.fmaxf(0, size.height - bottom_offset - AREA_BOTTOM_GAP - y));
        view.position = Vec2(0, -y);
        calculation_views.add(view);
    }

    private float hand_width()
    {
        return Math.fminf(HAND_MAX_WIDTH, size.width - 2 * SIDE_MARGIN);
    }

    private float panel_width()
    {
        return Math.fminf(PANEL_MAX_WIDTH, size.width - 2 * SIDE_MARGIN);
    }

    // Space between the top of the answer area and the bottom button bar
    private float area_height()
    {
        return Math.fmaxf(0, size.height - bottom_offset - AREA_BOTTOM_GAP - (top_offset + AREA_Y));
    }

    // Adds a centred label with its top edge y pixels below the top, and returns y + advance
    private static float add_label(Container parent, string text, float font_size, float y, float advance, Color color)
    {
        LabelControl label = new LabelControl();
        parent.add_child(label);
        label.font_size = font_size;
        label.text = text;
        label.color = color;
        label.outer_anchor = Vec2(0.5f, 1);
        label.inner_anchor = Vec2(0.5f, 1);
        label.position = Vec2(0, -y);
        return y + advance;
    }
}

// A points box that also reports Enter, so answers can be submitted from the keyboard
private class PointCalcAnswerInput : TextInputControl
{
    private const int MAX_LENGTH = 9;

    public signal void submitted();

    public PointCalcAnswerInput()
    {
        base("points", MAX_LENGTH);
    }

    protected override void on_key_press(KeyArgs key)
    {
        if (key.down && (key.keycode == KeyCode.RETURN || key.scancode == ScanCode.KP_ENTER))
        {
            key.handled = true;
            submitted();
            return;
        }

        base.on_key_press(key);
    }
}
