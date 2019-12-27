# Lumen

Lumen is a menu bar application for macOS that magically sets the screen
brightness based on your screen contents.

**You control Lumen simply by using your brightness keys - it'll automatically
learn your preferences.**

Lumen will automatically brighten the screen when you're looking at a dark
window (for example, a full-screen terminal) and it'll automatically darken the
screen when you're looking at a bright window (for example, a web browser).
This makes for a much more pleasant experience, especially at night.

## Demo

![Demo][demo]

Without Lumen, web pages are too bright, and the terminal is too dark to read.
With Lumen, it's perfect.

## Download

The easiest way to install Lumen is to use [Homebrew Cask][cask]:

```bash
brew cask install lumen
```

Cask makes it easy to manage updates too.

If you prefer, you can manually install the binary. You can find pre-built
binaries [here][releases].

**As of now, releases are not signed with a developer key. To open unsigned
applications, use [this method][opening-unsigned].**

You can also download and compile the code yourself, if you feel like it.

**Note: Lumen isn't supposed to work with auto brightness enabled, so be sure
to disable the "automatically adjust brightness as ambient light changes"
feature in System Preferences.**

## Contributing

Feature requests, bug reports, and pull requests are all appreciated.

## Related Projects

* [bencevans/lumenaire](https://github.com/bencevans/lumenaire) - a **cross
  platform** implementation of Lumen written in **Node.js**
* [epilande/lux](https://github.com/epilande/lux) - a **cross platform**
  implementation of Lumen written in **Node.js**
* [meh/dux](https://github.com/meh/dux) - a **Linux** implementation of Lumen
  (with some extra features) written in **Rust**
* [autolume/autolux](https://github.com/autolume/autolux) - a **Linux**
  implementation of Lumen written in **Python**
* [AlaaAlShammaa/Luminance](https://github.com/AlaaAlShammaa/Luminance) - a
  **Windows** implementation of Lumen written in **Java**

Note: I haven't personally audited the code from these projects.

## License

Copyright (c) 2015-2019 Anish Athalye. Released under GPLv3. See
[LICENSE.txt][license] for details.

[demo]: assets/demo.gif
[cask]: https://caskroom.github.io/
[opening-unsigned]: https://support.apple.com/kb/ph14369
[releases]: https://github.com/anishathalye/lumen/releases
[license]: LICENSE.txt
