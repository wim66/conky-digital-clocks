# Conky Flip Clock

![Conky Flip Clock](preview.png)

Conky Flip Clock is a stylish and minimalist flip clock widget for Conky, built using Lua and Cairo Graphics. This widget provides an elegant clock display with customizable colors and background elements.

## Features

- **Flip Clock Display**: Show the current time in a classic flip clock style.
- **Background and Borders**: Customizable colors and background effects.
- **Responsive Design**: Adapts to various screen resolutions and widget sizes.
- **Compatibility**: Supports both Cairo and fallback options when certain modules are unavailable.

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/wim66/Conky-flip-clock.git
   ```
2. **Requirements**:
   - Ensure Conky is installed.
   - Install the Cairo library:
     ```bash
     sudo apt install libcairo2-dev
     ```

3. **Customize Settings** (optional):
   - Modify colors and other parameters in `settings.lua`.
   - Check the script files `clock.lua` and `background.lua` for advanced customization.

## Troubleshooting

- **Cairo Module Not Found**:
  If the `cairo_xlib` module is unavailable, the script automatically falls back. Ensure Cairo is properly installed.

## License

This project is licensed under the [MIT License](LICENSE).
