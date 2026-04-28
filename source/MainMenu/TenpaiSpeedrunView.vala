using Engine;
using Gee;

class TenpaiSpeedrunView : MenuSubView
{
    private enum Phase
    {
        PLAYING,
        RESULTS
    }

    private Options options;
    private RandomClass rnd;

    // Game state
    private ArrayList<Tile> hand = new ArrayList<Tile>();
    private ArrayList<Tile> wall = new ArrayList<Tile>();
    private ArrayList<Tile> discards = new ArrayList<Tile>();
    private bool drew_tile = false;
    private Tile? drawn_tile = null;
    private int draw_count = 0;
    private bool run_succeeded = true;
    private Wind round_wind = Wind.EAST;
    private Wind seat_wind = Wind.EAST;
    private bool timer_running = false;
    private bool timer_started = false;
    private float timer_start = 0;
    private float current_elapsed = 0;
    private float final_elapsed = 0;

    // Persistent stats
    private TenpaiSpeedrunStats stats;

    // Phase
    private Phase phase = Phase.PLAYING;

    // Playing UI
    private LabelControl? round_wind_label;
    private LabelControl? seat_wind_label;
    private LabelControl? timer_label;
    private LabelControl? draw_label;
    private LabelControl? hint_label;
    private LabelControl? discard_header_label;
    private MenuTextButton? draw_button;
    private TenpaiTileFieldView? tile_field;
    private TenpaiDiscardPileView? discard_pile_view;

    // Audio cues for the draw/discard cycle.
    private Sound? draw_sound;
    private Sound? discard_sound;

    // Results UI
    private View2D? results_container;

    // Menu buttons (controlled in get_menu_buttons override and updated dynamically)
    private MenuTextButton? back_button;
    private MenuTextButton? restart_button;
    private MenuTextButton? main_menu_button;

    public TenpaiSpeedrunView()
    {
        options = new Options.from_disk();
        rnd = new RandomClass();
        stats = new TenpaiSpeedrunStats();
    }

    protected override string get_name()
    {
        return "Tenpai Speedrun";
    }

    protected override ArrayList<MenuTextButton>? get_menu_buttons()
    {
        ArrayList<MenuTextButton> buttons = new ArrayList<MenuTextButton>();

        restart_button = new MenuTextButton("MenuButton", "Restart");
        restart_button.clicked.connect(restart_clicked);
        buttons.add(restart_button);

        main_menu_button = new MenuTextButton("MenuButton", "Main Menu");
        main_menu_button.clicked.connect(main_menu_clicked);
        buttons.add(main_menu_button);

        return buttons;
    }

    protected override void load_finished()
    {
        if (restart_button != null) restart_button.visible = false;
        if (main_menu_button != null) main_menu_button.visible = false;

        // Hide the main-menu rotating tile / OpenRiichi banner while the
        // speedrun mode is active so they don't compete with the game UI.
        MainWindow? mw = window as MainWindow;
        if (mw != null)
            mw.set_main_menu_decoration_visible(false);

        // Load the same draw/discard cues the regular gameplay uses.
        draw_sound = store.audio_player.load_sound("draw");
        discard_sound = store.audio_player.load_sound("discard");

        build_playing_ui();
        start_new_run();
    }

    public override void removed()
    {
        // Restore the main-menu decoration when leaving the speedrun mode.
        MainWindow? mw = window as MainWindow;
        if (mw != null)
            mw.set_main_menu_decoration_visible(true);
    }

    private void build_playing_ui()
    {
        back_button = new MenuTextButton("MenuButtonSmall", "Back");
        add_child(back_button);
        back_button.outer_anchor = Vec2(1, 1);
        back_button.inner_anchor = Vec2(1, 1);
        back_button.position = Vec2(-15, -10);
        back_button.font_size = 18;
        back_button.clicked.connect(do_back);

        round_wind_label = new LabelControl();
        add_child(round_wind_label);
        round_wind_label.font_size = 26;
        round_wind_label.outer_anchor = Vec2(0.5f, 1);
        round_wind_label.inner_anchor = Vec2(0.5f, 1);
        round_wind_label.position = Vec2(-180, -(top_offset + 18));

        seat_wind_label = new LabelControl();
        add_child(seat_wind_label);
        seat_wind_label.font_size = 26;
        seat_wind_label.outer_anchor = Vec2(0.5f, 1);
        seat_wind_label.inner_anchor = Vec2(0.5f, 1);
        seat_wind_label.position = Vec2(180, -(top_offset + 18));

        timer_label = new LabelControl();
        add_child(timer_label);
        timer_label.font_size = 32;
        timer_label.outer_anchor = Vec2(0.5f, 1);
        timer_label.inner_anchor = Vec2(0.5f, 1);
        timer_label.position = Vec2(-150, -(top_offset + 65));

        draw_label = new LabelControl();
        add_child(draw_label);
        draw_label.font_size = 32;
        draw_label.outer_anchor = Vec2(0.5f, 1);
        draw_label.inner_anchor = Vec2(0.5f, 1);
        draw_label.position = Vec2(150, -(top_offset + 65));

        hint_label = new LabelControl();
        add_child(hint_label);
        hint_label.font_size = 22;
        hint_label.outer_anchor = Vec2(0.5f, 1);
        hint_label.inner_anchor = Vec2(0.5f, 1);
        hint_label.position = Vec2(0, -(top_offset + 120));

        draw_button = new MenuTextButton("MenuButtonSmall", "Draw Tile");
        add_child(draw_button);
        draw_button.outer_anchor = Vec2(0.5f, 1);
        draw_button.inner_anchor = Vec2(0.5f, 1);
        draw_button.position = Vec2(0, -(top_offset + 170));
        draw_button.clicked.connect(draw_clicked);

        tile_field = new TenpaiTileFieldView(options);
        add_child(tile_field);
        tile_field.resize_style = ResizeStyle.RELATIVE;
        tile_field.relative_size = Size2(1, 1);
        tile_field.tile_clicked.connect(on_tile_clicked);

        discard_header_label = new LabelControl();
        add_child(discard_header_label);
        discard_header_label.font_size = 16;
        discard_header_label.outer_anchor = Vec2(0, 1);
        discard_header_label.inner_anchor = Vec2(0, 1);
        discard_header_label.position = Vec2(15, -8);

        discard_pile_view = new TenpaiDiscardPileView(options);
        add_child(discard_pile_view);
        discard_pile_view.resize_style = ResizeStyle.ABSOLUTE;
        discard_pile_view.size = Size2(280, 380);
        discard_pile_view.outer_anchor = Vec2(0, 1);
        discard_pile_view.inner_anchor = Vec2(0, 1);
        discard_pile_view.position = Vec2(15, -28);
    }

    private void start_new_run()
    {
        phase = Phase.PLAYING;
        drew_tile = false;
        drawn_tile = null;
        draw_count = 0;
        run_succeeded = true;
        timer_running = false;
        timer_started = false;
        current_elapsed = 0;
        final_elapsed = 0;
        hand.clear();
        wall.clear();
        discards.clear();

        round_wind = (Wind)rnd.int_range(0, 4);
        seat_wind  = (Wind)rnd.int_range(0, 4);

        // Build a fresh, shuffled 136-tile wall and deal 13 tiles. If the
        // initial deal is already tenpai, reshuffle so the player has at
        // least one decision to make.
        int safety = 0;
        do
        {
            wall = build_shuffled_wall();
            hand.clear();
            for (int i = 0; i < 13; i++)
                hand.add(wall.remove_at(0));
            safety++;
        }
        while (TileRules.in_tenpai(hand, null) && safety < 20);

        if (round_wind_label != null) round_wind_label.visible = true;
        if (seat_wind_label != null) seat_wind_label.visible = true;
        if (timer_label != null) timer_label.visible = true;
        if (draw_label != null) draw_label.visible = true;
        if (hint_label != null) hint_label.visible = true;
        if (draw_button != null) draw_button.visible = true;
        if (tile_field != null)
        {
            tile_field.visible = true;
            // Restore the tile field to fill the whole view for play.
            tile_field.relative_size = Size2(1, 1);
            tile_field.outer_anchor = Vec2(0.5f, 0.5f);
            tile_field.inner_anchor = Vec2(0.5f, 0.5f);
            tile_field.position = Vec2(0, 0);
        }
        if (discard_header_label != null) discard_header_label.visible = true;
        if (discard_pile_view != null) discard_pile_view.visible = true;
        if (discard_pile_view != null) discard_pile_view.set_discards(discards);

        if (results_container != null)
        {
            remove_child(results_container);
            results_container = null;
        }

        if (back_button != null) back_button.visible = true;
        if (restart_button != null) restart_button.visible = false;
        if (main_menu_button != null) main_menu_button.visible = false;

        update_text();
        refresh_tiles();
    }

    private ArrayList<Tile> build_shuffled_wall()
    {
        ArrayList<Tile> tiles = new ArrayList<Tile>();
        for (int i = 0; i < 136; i++)
        {
            TileType type = (TileType)((i / 4) + 1);
            tiles.add(new Tile(i, type, false));
        }

        // Fisher-Yates shuffle.
        for (int i = tiles.size - 1; i > 0; i--)
        {
            int j = rnd.int_range(0, i + 1);
            if (j == i)
                continue;
            Tile tmp = tiles[i];
            tiles[i] = tiles[j];
            tiles[j] = tmp;
        }

        return tiles;
    }

    private void refresh_tiles()
    {
        if (tile_field == null)
            return;

        // Sort the resting hand without the just-drawn tile so the row stays
        // stable when a tile is drawn. The drawn tile is shown to the side.
        ArrayList<Tile> resting = new ArrayList<Tile>();
        resting.add_all(hand);
        if (drawn_tile != null)
            resting.remove(drawn_tile);
        ArrayList<Tile> sorted = Tile.sort_tiles_type(resting);

        tile_field.set_hand(sorted, drawn_tile, drew_tile);

        if (draw_button != null)
            draw_button.enabled = !drew_tile;
    }

    private void update_text()
    {
        if (timer_label != null)
            timer_label.text = "Time: %.2fs".printf(timer_running || phase == Phase.RESULTS ? current_elapsed : 0);
        if (draw_label != null)
            draw_label.text = "Draws: %d".printf(draw_count);
        if (discard_header_label != null)
            discard_header_label.text = "Discards (%d)".printf(discards.size);

        // Highlight in gold when seat wind == round wind (double yakuhai).
        bool double_wind = round_wind == seat_wind;
        Color wind_color = double_wind ? Color(1, 0.85f, 0.3f, 1) : Color.white();

        if (round_wind_label != null)
        {
            round_wind_label.text = "Round: %s %s".printf(WIND_TO_KANJI(round_wind), WIND_TO_STRING(round_wind));
            round_wind_label.color = wind_color;
        }
        if (seat_wind_label != null)
        {
            seat_wind_label.text = "Seat: %s %s".printf(WIND_TO_KANJI(seat_wind), WIND_TO_STRING(seat_wind));
            seat_wind_label.color = wind_color;
        }

        if (hint_label != null)
        {
            if (phase != Phase.PLAYING)
                hint_label.text = "";
            else if (draw_count == 0)
                hint_label.text = "Click \"Draw Tile\" to start.";
            else
                hint_label.text = "Pick a tile to discard.";
        }
    }

    protected override void process(DeltaArgs delta)
    {
        if (timer_running)
        {
            if (!timer_started)
            {
                timer_start = delta.time;
                timer_started = true;
            }
            current_elapsed = delta.time - timer_start;
            update_text();
        }
    }

    private void draw_clicked()
    {
        if (phase != Phase.PLAYING || drew_tile)
            return;

        // Wall exhaustion ends the run as a 流局-style failure. We do NOT
        // reshuffle a fresh 136-tile wall on top of the existing hand and
        // discards: that would create more than 4 copies of some tile types
        // in play, which breaks both riichi rules and tenpai-detection
        // integrity.
        if (wall.size == 0)
        {
            finish_run_exhausted();
            return;
        }

        Tile drawn = wall.remove_at(0);
        hand.add(drawn);
        drawn_tile = drawn;
        drew_tile = true;
        draw_count++;

        if (draw_sound != null)
            draw_sound.play();

        if (!timer_running)
        {
            timer_running = true;
            timer_started = false;
        }

        // After the first draw the loop is fully driven by discards, so the
        // start button stops being useful — hide it.
        if (draw_button != null)
            draw_button.visible = false;

        refresh_tiles();
        update_text();
    }

    private void on_tile_clicked(Tile to_discard)
    {
        if (phase != Phase.PLAYING || !drew_tile)
            return;

        if (!hand.remove(to_discard))
            return;

        discards.add(to_discard);
        if (discard_pile_view != null)
            discard_pile_view.set_discards(discards);

        if (discard_sound != null)
            discard_sound.play();

        drew_tile = false;
        drawn_tile = null;

        if (TileRules.in_tenpai(hand, null))
        {
            finish_run();
            return;
        }

        // After the very first draw, every discard is immediately followed by
        // the next draw — clicking the button between discards is pointless.
        draw_clicked();
    }

    private void finish_run()
    {
        timer_running = false;
        final_elapsed = current_elapsed;
        phase = Phase.RESULTS;
        run_succeeded = true;

        // Refresh the field so it shows the final 13-tile tenpai hand
        // (the just-discarded tile is gone, drawn-tile slot is empty).
        refresh_tiles();

        ArrayList<Tile> waits = compute_wait_tiles(hand);
        int wait_count = waits.size;
        string winning_tile = wait_count > 0 ? TILE_TYPE_TO_STRING(waits[0].tile_type) : "-";
        bool furiten = check_furiten(waits, discards);

        TenpaiSpeedrunRecord record = new TenpaiSpeedrunRecord(
            new DateTime.now_local().format("%F %H:%M:%S"),
            (double)final_elapsed,
            draw_count,
            wait_count,
            winning_tile,
            furiten
        );
        stats.add_record(record);

        build_results_ui(record, waits);
    }

    // Called when the wall is empty and the player still hasn't reached
    // tenpai. The run is recorded as a failure (not saved to stats so
    // averages stay clean) and a "Wall Exhausted" screen is shown.
    private void finish_run_exhausted()
    {
        timer_running = false;
        final_elapsed = current_elapsed;
        phase = Phase.RESULTS;
        run_succeeded = false;

        // No drawn tile to merge back; just show the resting hand as it
        // stands at exhaustion.
        refresh_tiles();

        build_failure_results_ui();
    }

    // Self-furiten: any of the player's wait tile types appears in their own
    // discard pile.
    private static bool check_furiten(ArrayList<Tile> waits, ArrayList<Tile> discards)
    {
        foreach (Tile w in waits)
            foreach (Tile d in discards)
                if (w.tile_type == d.tile_type)
                    return true;
        return false;
    }

    private static ArrayList<Tile> compute_wait_tiles(ArrayList<Tile> tenpai_hand)
    {
        ArrayList<Tile> waits = new ArrayList<Tile>();
        for (int t = (int)TileType.MAN1; t <= (int)TileType.CHUN; t++)
        {
            ArrayList<Tile> probe = new ArrayList<Tile>();
            probe.add_all(tenpai_hand);
            probe.add(new Tile(-1, (TileType)t, false));
            if (TileRules.winning_hand(probe, null))
                waits.add(new Tile(-1, (TileType)t, false));
        }
        return waits;
    }

    // Hide playing-screen chrome, dock the tile field at the bottom so the
    // hand stays visible, swap the bottom-row buttons, and create the
    // results_container. Returns the starting y for content labels.
    private float setup_results_chrome()
    {
        if (round_wind_label != null) round_wind_label.visible = false;
        if (seat_wind_label != null) seat_wind_label.visible = false;
        if (timer_label != null) timer_label.visible = false;
        if (draw_label != null) draw_label.visible = false;
        if (hint_label != null) hint_label.visible = false;
        if (draw_button != null) draw_button.visible = false;

        // Discard pile + header stay visible so the player can review which
        // tiles they discarded and verify the furiten flag against them.

        if (tile_field != null)
        {
            tile_field.visible = true;
            tile_field.relative_size = Size2(1.0f, 0.32f);
            tile_field.outer_anchor = Vec2(0.5f, 0);
            tile_field.inner_anchor = Vec2(0.5f, 0);
            tile_field.position = Vec2(0, bottom_offset + 20);
        }

        if (back_button != null) back_button.visible = false;
        if (restart_button != null) restart_button.visible = true;
        if (main_menu_button != null) main_menu_button.visible = true;

        results_container = new View2D();
        add_child(results_container);
        results_container.resize_style = ResizeStyle.RELATIVE;

        return -(top_offset + 30);
    }

    private void build_results_ui(TenpaiSpeedrunRecord record, ArrayList<Tile> waits)
    {
        float y = setup_results_chrome();
        const float line_height = 32;

        y = add_results_label(results_container, "Tenpai!", 42, y, line_height + 18, Color(1, 0.95f, 0.4f, 1));
        y -= 10;

        if (record.is_furiten)
        {
            y = add_results_label(results_container,
                "(Furiten: your wait was already in your discards)",
                22, y, line_height - 4, Color(1, 0.45f, 0.45f, 1));
        }

        y = add_results_label(results_container,
            "Time: %.2fs    Draws: %d    Waits: %d (%s)".printf(
                record.time_seconds,
                record.draw_count,
                record.wait_tile_count,
                format_wait_summary(waits)
            ),
            26, y, line_height, Color.white());

        y -= 16;
        y = add_results_label(results_container, "── Statistics ──", 22, y, line_height,
            Color(0.7f, 0.85f, 1.0f, 1));

        int[] ranges = { 5, 10, 25, 100 };
        foreach (int n in ranges)
        {
            TenpaiSpeedrunRangeStats r = stats.range_stats(n);
            string text;
            if (r.count == 0)
                text = "Last %d:  (no data)".printf(n);
            else
                text = "Last %d (%d): avg %.2fs / %.1f draws,  best %.2fs / %d draws".printf(
                    n, r.count, r.avg_time, r.avg_draws, r.best_time, r.best_draws);
            y = add_results_label(results_container, text, 20, y, line_height - 4, Color.white());
        }

        TenpaiSpeedrunRangeStats all = stats.range_stats(int.MAX);
        if (all.count > 0)
        {
            y = add_results_label(results_container,
                "All-time (%d): avg %.2fs / %.1f draws,  best %.2fs / %d draws,  worst %.2fs / %d draws".printf(
                    all.count, all.avg_time, all.avg_draws,
                    all.best_time, all.best_draws,
                    all.worst_time, all.worst_draws),
                20, y, line_height - 4, Color.white());
        }

        y -= 12;
        y = add_results_label(results_container, "── Habits ──", 22, y, line_height,
            Color(0.7f, 0.85f, 1.0f, 1));

        y = add_results_label(results_container,
            "Average wait-tile count at tenpai: %.2f".printf(stats.average_wait_tile_count()),
            20, y, line_height - 4, Color.white());

        int single = stats.single_wait_attempt_count();
        double pct = stats.total_attempts > 0 ? 100.0 * single / stats.total_attempts : 0.0;
        y = add_results_label(results_container,
            "Single-wait finishes: %d / %d (%.1f%%)".printf(single, stats.total_attempts, pct),
            20, y, line_height - 4, Color.white());

        y = add_results_label(results_container,
            "Most common finishing wait tile: " + stats.most_common_finishing_tile(),
            20, y, line_height - 4, Color.white());

        int fur = stats.furiten_attempt_count();
        double fur_pct = stats.total_attempts > 0 ? 100.0 * fur / stats.total_attempts : 0.0;
        y = add_results_label(results_container,
            "Furiten finishes: %d / %d (%.1f%%)".printf(fur, stats.total_attempts, fur_pct),
            20, y, line_height - 4, Color.white());

        update_text();
    }

    // Drawn when the player exhausts the wall before reaching tenpai.
    // Intentionally minimal: shows the failure clearly and the run is NOT
    // saved to stats so the rolling averages stay honest about real tenpai
    // attempts.
    private void build_failure_results_ui()
    {
        float y = setup_results_chrome();
        const float line_height = 32;

        y = add_results_label(results_container, "Wall Exhausted", 42, y, line_height + 18,
            Color(1, 0.45f, 0.45f, 1));
        y -= 10;

        y = add_results_label(results_container,
            "You drew all %d tiles without reaching tenpai.".printf(draw_count),
            24, y, line_height, Color.white());

        y -= 8;
        y = add_results_label(results_container,
            "Time: %.2fs    Discards: %d".printf(final_elapsed, discards.size),
            22, y, line_height, Color(0.85f, 0.85f, 0.85f, 1));

        y -= 16;
        y = add_results_label(results_container,
            "(This run was not recorded; rolling stats only count tenpai finishes.)",
            18, y, line_height - 4, Color(0.7f, 0.7f, 0.7f, 1));

        update_text();
    }

    private static string format_wait_summary(ArrayList<Tile> waits)
    {
        if (waits.size == 0)
            return "-";

        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < waits.size; i++)
        {
            if (i > 0)
                sb.append(", ");
            sb.append(TILE_TYPE_TO_STRING(waits[i].tile_type));
        }
        return sb.str;
    }

    private static float add_results_label(Container parent, string text, float font_size,
                                           float y, float advance, Color color)
    {
        LabelControl label = new LabelControl();
        parent.add_child(label);
        label.font_size = font_size;
        label.text = text;
        label.color = color;
        label.outer_anchor = Vec2(0.5f, 1);
        label.inner_anchor = Vec2(0.5f, 1);
        label.position = Vec2(0, y);
        return y - advance;
    }

    private void restart_clicked()
    {
        start_new_run();
    }

    private void main_menu_clicked()
    {
        do_back();
    }
}

private class TenpaiTileFieldView : View3D
{
    // Worst case is 13 hand tiles + a drawn tile separated by a gap.
    // The right edge of the drawn tile sits ~+8 tile-widths from screen
    // center, the left edge of the leftmost hand tile sits at -6.5 — so we
    // need a horizontal half-width of at least 8 tile-widths.
    private const int MAX_HAND_SIZE = 16;
    private const float DRAWN_GAP = 1.5f; // in tile-width units, between resting hand and drawn tile
    private const float FOV_DEGREES = 50f;
    private const float FIT_MARGIN = 1.15f;

    private ArrayList<RenderTile> render_tiles = new ArrayList<RenderTile>();
    private Options options;
    private bool clickable = false;
    private Vec3 tile_size;
    private float tile_scale = 1.5f;
    private TargetWorldCamera? camera = null;

    // Stand the tile up so its face points toward the camera (which sits on
    // +Z). +90° pitch around X maps the original face normal (+Y) to +Z and
    // turns the tile's length axis into the screen's vertical axis.
    private static Quat upright_rotation()
    {
        return Quat.from_euler(0, 0.5f, 0);
    }

    public signal void tile_clicked(Tile tile);

    public TenpaiTileFieldView(Options options)
    {
        this.options = options;
    }

    public override void added()
    {
        // Probe a tile so we can read its bounding box for layout maths.
        RenderTile probe = new RenderTile();
        world.add_object(probe);
        tile_size = probe.obb.mul_scalar(tile_scale);
        world.remove_object(probe);

        // Soft front lighting — kept subtle so hover tinting stays visible.
        // Positions are absolute (in world units, not tile-size-relative) so
        // every speedrun-mode View3D can share the same lighting setup
        // regardless of tile scale — see TenpaiDiscardPileView.added().
        world.add_object(new WorldLight() { position = Vec3(0, 5, 6), intensity = 4 });
        world.add_object(new WorldLight() { position = Vec3(-5, 3, 5), intensity = 2 });
        world.add_object(new WorldLight() { position = Vec3( 5, 3, 5), intensity = 2 });

        // Camera looks straight at the tile row, framing it horizontally.
        WorldObject target = new WorldObject();
        world.add_object(target);
        target.position = Vec3(0, tile_size.z / 2, 0);

        camera = new TargetWorldCamera(target);
        world.add_object(camera);
        world.active_camera = camera;
        camera.view_angle = FOV_DEGREES;
        update_camera_position();

        world.do_picking = true;
    }

    protected override void resized()
    {
        update_camera_position();
    }

    // Pick a camera distance that always fits MAX_HAND_SIZE tiles horizontally
    // (with a small margin) given the view's current aspect ratio.
    private void update_camera_position()
    {
        if (camera == null)
            return;

        Rectangle r = rect;
        float aspect = (r.width > 0 && r.height > 0) ? (float)r.width / (float)r.height : 16f / 9f;

        float fov_half_tan = (float)Math.tan(camera.view_angle * Math.PI / 360.0);
        // The engine uses view_angle for the larger of the two axes:
        // landscape -> horizontal FOV; portrait -> vertical FOV.
        float horizontal_half_tan = aspect >= 1 ? fov_half_tan : fov_half_tan * aspect;
        float vertical_half_tan   = aspect >= 1 ? fov_half_tan / aspect : fov_half_tan;

        float distance_for_width  = (MAX_HAND_SIZE * tile_size.x / 2) / horizontal_half_tan * FIT_MARGIN;
        float distance_for_height = (tile_size.z / 2) / vertical_half_tan * FIT_MARGIN;
        float distance = Math.fmaxf(distance_for_width, distance_for_height);

        camera.position = Vec3(0, tile_size.z / 2, distance);
    }

    public void set_hand(ArrayList<Tile> resting, Tile? drawn, bool clickable)
    {
        this.clickable = clickable;

        foreach (RenderTile rt in render_tiles)
            world.remove_object(rt);
        render_tiles.clear();

        // Resting hand: centered around x=0, regardless of whether a drawn
        // tile is present. This way the hand never shifts when a tile is
        // drawn or returned.
        int n = resting.size;
        for (int i = 0; i < n; i++)
            spawn_tile(resting[i], (i - (n - 1) / 2.0f) * tile_size.x);

        // Drawn tile sits to the right with a clear gap.
        if (drawn != null)
        {
            float anchor = (n - 1) / 2.0f; // center of last resting tile, in tile-widths from screen center
            float drawn_x = (anchor + DRAWN_GAP) * tile_size.x;
            spawn_tile(drawn, drawn_x);
        }
    }

    private void spawn_tile(Tile tile, float x)
    {
        RenderTile rt = new RenderTile()
        {
            tile_type = tile,
            model_quality = options.model_quality,
            texture_type = options.tile_textures
        };
        world.add_object(rt);
        rt.scale = tile_scale;
        rt.front_color = options.tile_fore_color;
        rt.back_color = options.tile_back_color;
        rt.set_absolute_location(Vec3(x, tile_size.z / 2, 0), upright_rotation());

        rt.on_click.connect(rt_clicked);
        rt.on_mouse_over.connect(rt_mouse_over);
        rt.on_focus_lost.connect(rt_focus_lost);

        render_tiles.add(rt);
    }

    private void rt_clicked(WorldObject obj)
    {
        if (!clickable)
            return;
        RenderTile? rt = obj as RenderTile;
        if (rt != null)
            tile_clicked(rt.tile_type);
    }

    private void rt_mouse_over(WorldObject obj)
    {
        if (!clickable)
            return;
        RenderTile? rt = obj as RenderTile;
        if (rt != null)
            rt.hovered = true;
    }

    private void rt_focus_lost(WorldObject obj)
    {
        RenderTile? rt = obj as RenderTile;
        if (rt != null)
            rt.hovered = false;
    }
}

private class TenpaiDiscardPileView : View3D
{
    private const int TILES_PER_ROW = 6;
    // Camera frames this many rows. More discards still render and are tracked
    // for furiten, just below the visible bottom of the pile.
    private const int VISIBLE_ROWS = 6;
    private const float TILE_SCALE = 0.85f;
    private const float ROW_GAP_RATIO = 0.05f; // small extra gap between rows
    private const float FOV_DEGREES = 45f;

    private ArrayList<RenderTile> render_tiles = new ArrayList<RenderTile>();
    private ArrayList<Tile> discards = new ArrayList<Tile>();
    private Options options;
    private Vec3 tile_size;
    private TargetWorldCamera? camera = null;
    private WorldObject? target = null;

    public TenpaiDiscardPileView(Options options)
    {
        this.options = options;
    }

    public override void added()
    {
        RenderTile probe = new RenderTile();
        world.add_object(probe);
        tile_size = probe.obb.mul_scalar(TILE_SCALE);
        world.remove_object(probe);

        // Same absolute light positions and intensities as the hand field
        // so both views are lit identically regardless of their tile scale.
        world.add_object(new WorldLight() { position = Vec3(0, 5, 6), intensity = 4 });
        world.add_object(new WorldLight() { position = Vec3(-5, 3, 5), intensity = 2 });
        world.add_object(new WorldLight() { position = Vec3( 5, 3, 5), intensity = 2 });

        target = new WorldObject();
        world.add_object(target);

        camera = new TargetWorldCamera(target);
        world.add_object(camera);
        world.active_camera = camera;
        camera.view_angle = FOV_DEGREES;

        update_camera();

        // Discards are display-only — no picking required.
        world.do_picking = false;
    }

    protected override void resized()
    {
        update_camera();
    }

    private float row_pitch()
    {
        return tile_size.z * (1.0f + ROW_GAP_RATIO);
    }

    private void update_camera()
    {
        if (camera == null || target == null)
            return;

        Rectangle r = rect;
        float aspect = (r.width > 0 && r.height > 0) ? (float)r.width / (float)r.height : 1.0f;
        float fov_half_tan = (float)Math.tan(camera.view_angle * Math.PI / 360.0);
        float horizontal_half_tan = aspect >= 1 ? fov_half_tan : fov_half_tan * aspect;
        float vertical_half_tan   = aspect >= 1 ? fov_half_tan / aspect : fov_half_tan;

        float content_width  = TILES_PER_ROW * tile_size.x;
        float content_height = VISIBLE_ROWS * row_pitch();

        // Center the camera vertically on the visible pile area; first row at top of frame.
        float center_y = -content_height / 2;
        target.position = Vec3(0, center_y, 0);

        float distance_for_width  = (content_width / 2) / horizontal_half_tan * 1.05f;
        float distance_for_height = (content_height / 2) / vertical_half_tan * 1.05f;
        float distance = Math.fmaxf(distance_for_width, distance_for_height);

        camera.position = Vec3(0, center_y, distance);
    }

    public void set_discards(ArrayList<Tile> discards_in)
    {
        discards.clear();
        discards.add_all(discards_in);

        foreach (RenderTile rt in render_tiles)
            world.remove_object(rt);
        render_tiles.clear();

        for (int i = 0; i < discards.size; i++)
        {
            int row = i / TILES_PER_ROW;
            int col = i % TILES_PER_ROW;

            float x = (col - (TILES_PER_ROW - 1) / 2.0f) * tile_size.x;
            float y = -(row + 0.5f) * row_pitch();

            RenderTile rt = new RenderTile()
            {
                tile_type = discards[i],
                model_quality = options.model_quality,
                texture_type = options.tile_textures
            };
            world.add_object(rt);
            rt.scale = TILE_SCALE;
            rt.front_color = options.tile_fore_color;
            rt.back_color = options.tile_back_color;
            rt.set_absolute_location(Vec3(x, y, 0), Quat.from_euler(0, 0.5f, 0));

            render_tiles.add(rt);
        }
    }
}
