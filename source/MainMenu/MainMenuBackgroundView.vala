using Engine;

class MainMenuBackgroundView : View2D
{
    private TileMenuView tile_view;
    private ImageControl text;
    private TileTextureEnum texture_type;
    private Color tile_front_color;
    private Color tile_back_color;

    public MainMenuBackgroundView(TileTextureEnum texture_type, Color tile_front_color, Color tile_back_color)
    {
        tile_view = new TileMenuView();
        this.texture_type = texture_type;
        this.tile_front_color = tile_front_color;
        this.tile_back_color = tile_back_color;
    }

    public override void added()
    {
        add_child(new MainMenuBackgroundImageView());

        add_child(tile_view);
        tile_view.texture_type = texture_type;
        tile_view.front_color = tile_front_color;
        tile_view.back_color = tile_back_color;
        tile_view.inner_anchor = Vec2(0, 0.5f);
        tile_view.outer_anchor = Vec2(0, 0.5f);

        text = new ImageControl("Menu/OpenRiichi");
        add_child(text);
        text.inner_anchor = Vec2(0.5f, 1);
        text.outer_anchor = Vec2(0.5f, 1);
    }

    public override void resized()
    {
        tile_view.size = Size2(size.width / 3, size.height / 3);
    }

    // Toggle the rotating tile and OpenRiichi banner. The table-image fill stays
    // so the area is never empty. Used by self-contained menu modes that want
    // their own clean backdrop.
    public void set_decoration_visible(bool visible)
    {
        if (tile_view != null) tile_view.visible = visible;
        if (text != null) text.visible = visible;
    }
}

class MainMenuBackgroundImageView : View2D
{
    public override void added()
    {
        ImageControl background = new ImageControl("field_high");
        add_child(background);
        background.resize_style = ResizeStyle.RELATIVE;
    }
}
