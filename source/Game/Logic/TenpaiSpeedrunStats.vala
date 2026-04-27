using Gee;
using Engine;

public class TenpaiSpeedrunRecord
{
    public TenpaiSpeedrunRecord(string timestamp, double time_seconds, int draw_count, int wait_tile_count, string winning_tile_type, bool is_furiten = false)
    {
        this.timestamp = timestamp;
        this.time_seconds = time_seconds;
        this.draw_count = draw_count;
        this.wait_tile_count = wait_tile_count;
        this.winning_tile_type = winning_tile_type;
        this.is_furiten = is_furiten;
    }

    public string serialize()
    {
        // Pipe-delimited so commas in fields stay safe even if format expands later.
        return "%s|%f|%d|%d|%s|%s".printf(
            timestamp,
            time_seconds,
            draw_count,
            wait_tile_count,
            winning_tile_type,
            is_furiten ? "1" : "0"
        );
    }

    public static TenpaiSpeedrunRecord? deserialize(string line)
    {
        string[] parts = line.split("|");
        if (parts.length < 5)
            return null;

        double time;
        if (!double.try_parse(parts[1], out time))
            return null;
        int draws = int.parse(parts[2]);
        int waits = int.parse(parts[3]);
        // Older records (pre-furiten) won't have a 6th field — default to false.
        bool furiten = parts.length >= 6 && parts[5].strip() == "1";

        return new TenpaiSpeedrunRecord(parts[0], time, draws, waits, parts[4], furiten);
    }

    public string timestamp { get; private set; }
    public double time_seconds { get; private set; }
    public int draw_count { get; private set; }
    public int wait_tile_count { get; private set; }
    public string winning_tile_type { get; private set; }
    public bool is_furiten { get; private set; }
}

public class TenpaiSpeedrunStats
{
    private const string FILE_NAME = "tenpai_speedrun.scores";
    private const string HEADER = "# OpenRiichi Tenpai Speedrun scores v1: timestamp|time_seconds|draw_count|wait_tile_count|winning_tile_type";

    public TenpaiSpeedrunStats()
    {
        records = new ArrayList<TenpaiSpeedrunRecord>();
        load();
    }

    private string file_path()
    {
        return GLib.Path.build_filename(Environment.get_user_dir(), FILE_NAME);
    }

    private void load()
    {
        records.clear();

        string path = file_path();
        if (!FileLoader.exists(path))
            return;

        string[]? lines = FileLoader.load(path);
        if (lines == null)
            return;

        foreach (string raw in lines)
        {
            string line = raw.strip();
            if (line.length == 0 || line.has_prefix("#"))
                continue;

            TenpaiSpeedrunRecord? rec = TenpaiSpeedrunRecord.deserialize(line);
            if (rec != null)
                records.add(rec);
        }
    }

    public void add_record(TenpaiSpeedrunRecord record)
    {
        records.add(record);

        // Make sure user dir exists before saving.
        GLib.DirUtils.create_with_parents(Environment.get_user_dir(), 0755);

        ArrayList<string> lines = new ArrayList<string>();
        lines.add(HEADER);
        foreach (TenpaiSpeedrunRecord r in records)
            lines.add(r.serialize());

        FileLoader.save(file_path(), lines.to_array());
    }

    public TenpaiSpeedrunRecord? latest()
    {
        return records.size == 0 ? null : records[records.size - 1];
    }

    public int total_attempts { get { return records.size; } }

    private ArrayList<TenpaiSpeedrunRecord> last_n(int n)
    {
        ArrayList<TenpaiSpeedrunRecord> slice = new ArrayList<TenpaiSpeedrunRecord>();
        int start = records.size - n;
        if (start < 0)
            start = 0;
        for (int i = start; i < records.size; i++)
            slice.add(records[i]);
        return slice;
    }

    public TenpaiSpeedrunRangeStats range_stats(int n)
    {
        ArrayList<TenpaiSpeedrunRecord> slice = last_n(n);

        int count = slice.size;
        if (count == 0)
            return new TenpaiSpeedrunRangeStats(0, 0, 0, 0, 0, 0, 0);

        double time_sum = 0;
        double draws_sum = 0;
        double best_time = slice[0].time_seconds;
        double worst_time = slice[0].time_seconds;
        int best_draws = slice[0].draw_count;
        int worst_draws = slice[0].draw_count;

        foreach (TenpaiSpeedrunRecord r in slice)
        {
            time_sum += r.time_seconds;
            draws_sum += r.draw_count;
            if (r.time_seconds < best_time)
                best_time = r.time_seconds;
            if (r.time_seconds > worst_time)
                worst_time = r.time_seconds;
            if (r.draw_count < best_draws)
                best_draws = r.draw_count;
            if (r.draw_count > worst_draws)
                worst_draws = r.draw_count;
        }

        return new TenpaiSpeedrunRangeStats(
            count,
            time_sum / count,
            draws_sum / count,
            best_time,
            worst_time,
            best_draws,
            worst_draws
        );
    }

    public double average_wait_tile_count()
    {
        if (records.size == 0)
            return 0;
        double sum = 0;
        foreach (TenpaiSpeedrunRecord r in records)
            sum += r.wait_tile_count;
        return sum / records.size;
    }

    // Returns the tile type that has finished tenpai most often (across all attempts).
    public string most_common_finishing_tile()
    {
        HashMap<string, int> counts = new HashMap<string, int>();
        foreach (TenpaiSpeedrunRecord r in records)
        {
            int prior = counts.has_key(r.winning_tile_type) ? counts[r.winning_tile_type] : 0;
            counts[r.winning_tile_type] = prior + 1;
        }

        string best = "—";
        int best_count = 0;
        foreach (var entry in counts.entries)
        {
            if (entry.value > best_count)
            {
                best_count = entry.value;
                best = entry.key;
            }
        }
        return best;
    }

    // Number of attempts whose final tenpai had only a single wait tile.
    public int single_wait_attempt_count()
    {
        int count = 0;
        foreach (TenpaiSpeedrunRecord r in records)
            if (r.wait_tile_count == 1)
                count++;
        return count;
    }

    // Number of attempts that finished while the player was in furiten.
    public int furiten_attempt_count()
    {
        int count = 0;
        foreach (TenpaiSpeedrunRecord r in records)
            if (r.is_furiten)
                count++;
        return count;
    }

    public ArrayList<TenpaiSpeedrunRecord> records { get; private set; }
}

public class TenpaiSpeedrunRangeStats
{
    public TenpaiSpeedrunRangeStats(int count, double avg_time, double avg_draws,
                                    double best_time, double worst_time,
                                    int best_draws, int worst_draws)
    {
        this.count = count;
        this.avg_time = avg_time;
        this.avg_draws = avg_draws;
        this.best_time = best_time;
        this.worst_time = worst_time;
        this.best_draws = best_draws;
        this.worst_draws = worst_draws;
    }

    public int count { get; private set; }
    public double avg_time { get; private set; }
    public double avg_draws { get; private set; }
    public double best_time { get; private set; }
    public double worst_time { get; private set; }
    public int best_draws { get; private set; }
    public int worst_draws { get; private set; }
}
