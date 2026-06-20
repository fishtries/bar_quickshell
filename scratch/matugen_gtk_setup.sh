#!/usr/bin/env bash

# 1. Update kitty config to include theme.conf instead of GruvBox
if grep -q "include theme.conf" ~/.config/kitty/kitty.conf; then
    echo "Kitty is already configured to include theme.conf"
else
    sed -i 's/include GruvBox_DarkHard.conf/include theme.conf/g' ~/.config/kitty/kitty.conf
    echo "Updated kitty.conf to include theme.conf"
fi

# 2. Add GTK templates to matugen config
mkdir -p ~/.config/matugen/templates

cat << 'EOF' > ~/.config/matugen/templates/gtk.css
@define-color accent_color {{colors.primary.default.hex}};
@define-color accent_fg_color {{colors.on_primary.default.hex}};
@define-color accent_bg_color {{colors.primary.default.hex}};
@define-color window_bg_color {{colors.surface.default.hex}};
@define-color window_fg_color {{colors.on_surface.default.hex}};
@define-color headerbar_bg_color {{colors.surface.default.hex}};
@define-color headerbar_fg_color {{colors.on_surface.default.hex}};
@define-color popover_bg_color {{colors.surface_container.default.hex}};
@define-color popover_fg_color {{colors.on_surface.default.hex}};
@define-color view_bg_color {{colors.surface.default.hex}};
@define-color view_fg_color {{colors.on_surface.default.hex}};
@define-color card_bg_color {{colors.surface_container_low.default.hex}};
@define-color card_fg_color {{colors.on_surface.default.hex}};
@define-color sidebar_bg_color @window_bg_color;
@define-color sidebar_fg_color @window_fg_color;
@define-color sidebar_border_color @window_bg_color;
@define-color sidebar_backdrop_color @window_bg_color;
EOF
echo "Created ~/.config/matugen/templates/gtk.css"

# Add GTK configurations to config.toml if not already present
if grep -q "templates.gtk3" ~/.config/matugen/config.toml; then
    echo "GTK templates are already configured in config.toml"
else
    cat << 'EOF' >> ~/.config/matugen/config.toml

[templates.gtk3]
input_path = "~/.config/matugen/templates/gtk.css"
output_path = "~/.config/gtk-3.0/gtk.css"

[templates.gtk4]
input_path = "~/.config/matugen/templates/gtk.css"
output_path = "~/.config/gtk-4.0/gtk.css"
EOF
    echo "Added GTK templates to ~/.config/matugen/config.toml"
fi
