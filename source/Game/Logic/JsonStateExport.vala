using Gee;

public class JsonStateExport : Object
{
    private static string state_file_path;
    private static GameState? game_state;

    public static void init()
    {
        string user_dir = Environment.get_user_dir();
        GLib.DirUtils.create_with_parents(user_dir, 0755);
        state_file_path = GLib.Path.build_filename(user_dir, "advisor_state.json");
    }

    public static void set_game_state(GameState state)
    {
        game_state = state;
    }

    public static void export_turn_decision(RoundState state)
    {
        if (state_file_path == null)
            init();

        string json = build_turn_json(state);
        write_file(json);
    }

    public static void export_call_decision(RoundState state, Tile discard_tile, RoundStatePlayer discard_player)
    {
        if (state_file_path == null)
            init();

        string json = build_call_json(state, discard_tile, discard_player);
        write_file(json);
    }

    private static string build_turn_json(RoundState state)
    {
        var sb = new StringBuilder();
        sb.append("{\n");
        sb.append("  \"decision_type\": \"turn\",\n");
        sb.append("  \"round_wind\": \"" + WIND_TO_STRING(state.round_wind) + "\",\n");
        sb.append("  \"seat_wind\": \"" + WIND_TO_STRING(state.self.wind) + "\",\n");
        sb.append("  \"dealer\": " + (state.dealer == state.self.index ? "true" : "false") + ",\n");
        append_game_info(sb);

        // My hand
        sb.append("  \"hand\": [");
        sb.append(tiles_to_json(state.self.hand));
        sb.append("],\n");

        // Dora indicators
        sb.append("  \"dora_indicators\": [");
        sb.append(tiles_to_json(state.dora));
        sb.append("],\n");

        // Tiles remaining in wall
        sb.append("  \"tiles_remaining\": " + state.tiles_remaining.to_string() + ",\n");

        // My calls/melds
        sb.append("  \"my_calls\": [");
        sb.append(calls_to_json(state.self.calls));
        sb.append("],\n");

        // My discards
        sb.append("  \"my_discards\": [");
        sb.append(tiles_to_json(state.self.pond));
        sb.append("],\n");

        // My status
        sb.append("  \"in_riichi\": " + state.self.in_riichi.to_string() + ",\n");
        sb.append("  \"furiten\": " + state.self.in_furiten().to_string() + ",\n");

        // Other players
        sb.append("  \"opponents\": [\n");
        for (int i = 0; i < 4; i++)
        {
            RoundStatePlayer p = state.get_player(i);
            if (p.index == state.self.index)
                continue;

            sb.append("    {\n");
            sb.append("      \"seat\": " + p.index.to_string() + ",\n");
            sb.append("      \"wind\": \"" + WIND_TO_STRING(p.wind) + "\",\n");
            sb.append("      \"discards\": [" + tiles_to_json(p.pond) + "],\n");
            sb.append("      \"calls\": [" + calls_to_json(p.calls) + "],\n");
            sb.append("      \"in_riichi\": " + p.in_riichi.to_string() + "\n");
            sb.append("    },\n");
        }
        // Remove trailing comma
        if (sb.str.has_suffix(",\n"))
        {
            sb.truncate(sb.len - 2);
            sb.append("\n");
        }
        sb.append("  ],\n");

        // Available actions
        sb.append("  \"can_tsumo\": " + state.can_tsumo().to_string() + ",\n");
        sb.append("  \"can_riichi\": " + state.can_riichi().to_string() + ",\n");
        sb.append("  \"can_late_kan\": " + state.can_late_kan().to_string() + ",\n");
        sb.append("  \"can_closed_kan\": " + state.can_closed_kan().to_string() + ",\n");

        // Discard candidates
        sb.append("  \"discard_candidates\": [");
        ArrayList<Tile> discard_tiles = state.self.get_discard_tiles();
        sb.append(tiles_to_json(discard_tiles));
        sb.append("]\n");

        sb.append("}");
        return sb.str;
    }

    private static string build_call_json(RoundState state, Tile discard_tile, RoundStatePlayer discard_player)
    {
        var sb = new StringBuilder();
        sb.append("{\n");
        sb.append("  \"decision_type\": \"call\",\n");
        sb.append("  \"round_wind\": \"" + WIND_TO_STRING(state.round_wind) + "\",\n");
        sb.append("  \"seat_wind\": \"" + WIND_TO_STRING(state.self.wind) + "\",\n");
        sb.append("  \"dealer\": " + (state.dealer == state.self.index ? "true" : "false") + ",\n");
        append_game_info(sb);

        // The tile that was discarded
        sb.append("  \"offered_tile\": \"" + TILE_TYPE_TO_STRING(discard_tile.tile_type) + (discard_tile.dora ? "*" : "") + "\",\n");
        sb.append("  \"discarder_seat\": " + discard_player.index.to_string() + ",\n");
        sb.append("  \"discarder_wind\": \"" + WIND_TO_STRING(discard_player.wind) + "\",\n");

        // My hand
        sb.append("  \"hand\": [");
        sb.append(tiles_to_json(state.self.hand));
        sb.append("],\n");

        // Dora
        sb.append("  \"dora_indicators\": [");
        sb.append(tiles_to_json(state.dora));
        sb.append("],\n");

        sb.append("  \"tiles_remaining\": " + state.tiles_remaining.to_string() + ",\n");

        // My calls/melds
        sb.append("  \"my_calls\": [");
        sb.append(calls_to_json(state.self.calls));
        sb.append("],\n");

        // My discards
        sb.append("  \"my_discards\": [");
        sb.append(tiles_to_json(state.self.pond));
        sb.append("],\n");

        sb.append("  \"in_riichi\": " + state.self.in_riichi.to_string() + ",\n");
        sb.append("  \"furiten\": " + state.self.in_furiten().to_string() + ",\n");

        // Other players
        sb.append("  \"opponents\": [\n");
        for (int i = 0; i < 4; i++)
        {
            RoundStatePlayer p = state.get_player(i);
            if (p.index == state.self.index)
                continue;

            sb.append("    {\n");
            sb.append("      \"seat\": " + p.index.to_string() + ",\n");
            sb.append("      \"wind\": \"" + WIND_TO_STRING(p.wind) + "\",\n");
            sb.append("      \"discards\": [" + tiles_to_json(p.pond) + "],\n");
            sb.append("      \"calls\": [" + calls_to_json(p.calls) + "],\n");
            sb.append("      \"in_riichi\": " + p.in_riichi.to_string() + "\n");
            sb.append("    },\n");
        }
        if (sb.str.has_suffix(",\n"))
        {
            sb.truncate(sb.len - 2);
            sb.append("\n");
        }
        sb.append("  ],\n");

        // Available call actions
        sb.append("  \"can_ron\": " + state.can_ron(state.self).to_string() + ",\n");
        sb.append("  \"can_pon\": " + state.can_pon(state.self).to_string() + ",\n");
        sb.append("  \"can_chii\": " + state.can_chii(state.self).to_string() + ",\n");
        sb.append("  \"can_open_kan\": " + state.can_open_kan(state.self).to_string() + "\n");

        sb.append("}");
        return sb.str;
    }

    private static string tile_to_str(Tile tile)
    {
        return TILE_TYPE_TO_STRING(tile.tile_type) + (tile.dora ? "*" : "");
    }

    private static string tiles_to_json(ArrayList<Tile> tiles)
    {
        var sb = new StringBuilder();
        for (int i = 0; i < tiles.size; i++)
        {
            if (i > 0)
                sb.append(", ");
            sb.append("\"" + tile_to_str(tiles[i]) + "\"");
        }
        return sb.str;
    }

    private static string calls_to_json(ArrayList<RoundStateCall> calls)
    {
        var sb = new StringBuilder();
        for (int i = 0; i < calls.size; i++)
        {
            RoundStateCall call = calls[i];
            if (i > 0)
                sb.append(", ");

            string type_str;
            switch (call.call_type)
            {
            case RoundStateCall.CallType.CHII:
                type_str = "chii";
                break;
            case RoundStateCall.CallType.PON:
                type_str = "pon";
                break;
            case RoundStateCall.CallType.OPEN_KAN:
                type_str = "open_kan";
                break;
            case RoundStateCall.CallType.CLOSED_KAN:
                type_str = "closed_kan";
                break;
            case RoundStateCall.CallType.LATE_KAN:
                type_str = "late_kan";
                break;
            default:
                type_str = "unknown";
                break;
            }

            sb.append("{\"type\": \"" + type_str + "\", \"tiles\": [");
            sb.append(tiles_to_json(call.tiles));
            sb.append("]}");
        }
        return sb.str;
    }

    private static void append_game_info(StringBuilder sb)
    {
        if (game_state == null)
            return;

        sb.append("  \"current_round\": " + (game_state.current_round + 1).to_string() + ",\n");
        sb.append("  \"riichi_sticks\": " + game_state.riichi_count.to_string() + ",\n");

        // Player scores
        sb.append("  \"scores\": [\n");
        for (int i = 0; i < 4; i++)
        {
            GameScorePlayer p = game_state.get_player(i);
            if (i > 0)
                sb.append(",\n");
            sb.append("    {\"name\": \"" + p.name + "\", \"seat\": " + p.index.to_string() +
                       ", \"wind\": \"" + WIND_TO_STRING(p.wind) + "\", \"points\": " + p.points.to_string() + "}");
        }
        sb.append("\n  ],\n");
    }

    private static void write_file(string content)
    {
        try
        {
            Environment.log(LogType.INFO, "JsonStateExport", "Writing state to: " + state_file_path);
            GLib.FileUtils.set_contents(state_file_path, content);
            Environment.log(LogType.INFO, "JsonStateExport", "State file written successfully");
        }
        catch (GLib.Error e)
        {
            Environment.log(LogType.ERROR, "JsonStateExport", "Failed to write state file: " + e.message);
        }
    }
}
