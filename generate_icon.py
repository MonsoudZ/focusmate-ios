#!/usr/bin/env python3
"""
Generate Focusmate app icon PNG files
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

if not PIL_AVAILABLE:
    print("Installing Pillow...")
    import subprocess
    import sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "Pillow"])
    from PIL import Image, ImageDraw, ImageFont

def create_icon(size=1024):
    """Create a Focusmate app icon with FM text on purple gradient"""

    # Create image with gradient background
    img = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(img)

    # Create gradient (indigo to violet)
    for y in range(size):
        # Interpolate between start and end colors
        ratio = y / size
        r = int(79 + (124 - 79) * ratio)
        g = int(70 + (58 - 70) * ratio)
        b = int(229 + (237 - 229) * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b))

    # Add rounded corners
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = int(size * 0.2208)  # iOS standard corner radius
    mask_draw.rounded_rectangle([(0, 0), (size, size)], corner_radius, fill=255)

    # Apply mask
    output = Image.new('RGB', (size, size), (255, 255, 255))
    output.paste(img, (0, 0), mask)

    # Draw FM text
    draw = ImageDraw.Draw(output)

    # Try to use system font, fallback to default
    font_size = int(size * 0.47)
    try:
        # Try different font paths
        for font_path in [
            '/System/Library/Fonts/Helvetica.ttc',
            '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
            '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
        ]:
            try:
                font = ImageFont.truetype(font_path, font_size)
                break
            except:
                continue
        else:
            font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()

    # Draw text centered
    text = "FM"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    x = (size - text_width) // 2
    y = (size - text_height) // 2 - int(size * 0.05)

    draw.text((x, y), text, fill=(255, 255, 255), font=font)

    return output

def main():
    print("🎨 Generating Focusmate app icon...")

    # Create the 1024x1024 icon
    icon = create_icon(1024)
    output_path = 'focusmate/Assets.xcassets/AppIcon.appiconset/icon-1024.png'
    icon.save(output_path, 'PNG')
    print(f"✅ Created: {output_path}")

    # Create additional sizes if needed
    sizes = {
        'icon-20.png': 20,
        'icon-29.png': 29,
        'icon-40.png': 40,
        'icon-58.png': 58,
        'icon-60.png': 60,
        'icon-76.png': 76,
        'icon-80.png': 80,
        'icon-87.png': 87,
        'icon-120.png': 120,
        'icon-152.png': 152,
        'icon-167.png': 167,
        'icon-180.png': 180,
    }

    for filename, size in sizes.items():
        resized = icon.resize((size, size), Image.Resampling.LANCZOS)
        path = f'focusmate/Assets.xcassets/AppIcon.appiconset/{filename}'
        resized.save(path, 'PNG')
        print(f"✅ Created: {path}")

    print("\n🎉 All icons generated successfully!")
    print("📱 Now updating Contents.json...")

    return True

if __name__ == '__main__':
    main()
