# Corebrum Apps in the Robot menu

Super+Space → Robot → Corebrum Apps opens a launcher submenu with Search
marketplace and Run installed app. The marketplace search loads
`corebrum apps search` when requested. Selecting a result opens a terminal
with the release's tested configurations and prerequisites. The operator
confirms before installation, then presses any key to close the installation
window. Installed apps are listed locally and launch
in a terminal so errors and terminal app output are visible.

The desktop profile installs the menu helper and desktop entry. The
launcher claims that entry under Robot. Desktop uninstall removes both
files. The menu uses the existing Apps CLI for downloads, compatibility
checks, installation, and launch. The launcher test verifies the Robot row
and checks that it appears once. A stubbed CLI and Fuzzel verified selection,
requirements review, confirmation, and launch.
The installed launcher on Thor lists Corebrum Apps under Robot and finds it
from the root search.

Corebrum Apps and Corebrum Skills use the launcher chooser interface for
their action rows. Right enters either submenu and Left returns to Robot.
The standalone helpers still open Fuzzel when called directly.
