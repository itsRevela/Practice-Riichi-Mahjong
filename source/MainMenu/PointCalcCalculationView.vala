using Engine;
using Gee;

// Shows a PointCalcExplanation as three columns: han, fu and points.
// Each line has a left-aligned label and a right-aligned value.
class PointCalcCalculationView : View2D
{
    private const float COLUMN_GAP = 40;

    private PointCalcExplanation explanation;
    private ArrayList<ArrayList<CalculationRow>> columns = new ArrayList<ArrayList<CalculationRow>>();

    public PointCalcCalculationView(PointCalcExplanation explanation)
    {
        this.explanation = explanation;
        resize_style = ResizeStyle.ABSOLUTE;
    }

    public override void added()
    {
        columns.add(create_rows(explanation.han_lines));
        columns.add(create_rows(explanation.fu_lines));
        columns.add(create_rows(explanation.points_lines));
        layout();
    }

    protected override void resized()
    {
        layout();
    }

    private ArrayList<CalculationRow> create_rows(ArrayList<ExplanationLine> lines)
    {
        ArrayList<CalculationRow> rows = new ArrayList<CalculationRow>();

        foreach (ExplanationLine line in lines)
        {
            LabelControl label = create_label(line.label, line.style);
            label.inner_anchor = Vec2(0, 1);
            label.outer_anchor = Vec2(0, 1);

            LabelControl value = create_label(line.value, line.style);
            value.inner_anchor = Vec2(1, 1);
            value.outer_anchor = Vec2(0, 1);

            rows.add(new CalculationRow(label, value, line.style));
        }

        return rows;
    }

    private LabelControl create_label(string text, ExplanationLineStyle style)
    {
        LabelControl label = new LabelControl();
        add_child(label);
        label.text = text;
        label.font_size = font_size(style);
        label.color = color(style);
        return label;
    }

    private void layout()
    {
        if (columns.size == 0)
            return;

        float column_width = (size.width - COLUMN_GAP * (columns.size - 1)) / columns.size;

        for (int i = 0; i < columns.size; i++)
        {
            float x = i * (column_width + COLUMN_GAP);
            float y = 0;

            foreach (CalculationRow row in columns[i])
            {
                row.label.position = Vec2(x, -y);
                row.value.position = Vec2(x + column_width, -y);
                y += advance(row.style);
            }
        }
    }

    // Height of the tallest column, for callers that stack content below this view
    public float content_height
    {
        get
        {
            float tallest = 0;
            foreach (ArrayList<CalculationRow> rows in columns)
            {
                float height = 0;
                foreach (CalculationRow row in rows)
                    height += advance(row.style);
                tallest = Math.fmaxf(tallest, height);
            }
            return tallest;
        }
    }

    private static float font_size(ExplanationLineStyle style)
    {
        switch (style)
        {
        case ExplanationLineStyle.HEADING:
            return 22;
        case ExplanationLineStyle.TOTAL:
            return 19;
        case ExplanationLineStyle.NOTE:
            return 15;
        case ExplanationLineStyle.ITEM:
        default:
            return 17;
        }
    }

    private static float advance(ExplanationLineStyle style)
    {
        switch (style)
        {
        case ExplanationLineStyle.HEADING:
            return 30;
        case ExplanationLineStyle.TOTAL:
            return 25;
        case ExplanationLineStyle.NOTE:
            return 20;
        case ExplanationLineStyle.ITEM:
        default:
            return 22;
        }
    }

    private static Color color(ExplanationLineStyle style)
    {
        switch (style)
        {
        case ExplanationLineStyle.HEADING:
            return Color(0.7f, 0.85f, 1.0f, 1);
        case ExplanationLineStyle.TOTAL:
            return Color(1, 0.95f, 0.4f, 1);
        case ExplanationLineStyle.NOTE:
            return Color(0.7f, 0.7f, 0.7f, 1);
        case ExplanationLineStyle.ITEM:
        default:
            return Color.white();
        }
    }

    private class CalculationRow
    {
        public CalculationRow(LabelControl label, LabelControl value, ExplanationLineStyle style)
        {
            this.label = label;
            this.value = value;
            this.style = style;
        }

        public LabelControl label { get; private set; }
        public LabelControl value { get; private set; }
        public ExplanationLineStyle style { get; private set; }
    }
}
