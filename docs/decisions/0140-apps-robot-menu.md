# Corebrum Apps in the Robot menu

Super+Space → Robot → Corebrum Apps opens a launcher submenu with Search
marketplace, Run installed app, and Remove installed app. The marketplace search loads
`corebrum apps search` when requested. Selecting a result opens a terminal
with the release's tested configurations and prerequisites. The operator
confirms before installation, then presses any key to close the installation
window. Installed apps are listed locally and launch
in a terminal so errors and terminal app output are visible.

Remove installed app uses the same local list and asks for confirmation by
app ID. Cancel is the first choice. Confirmation runs `corebrum apps remove`
in a terminal to show the result. The command removes all installed releases
of the selected app for the current account.

The desktop profile installs the menu helper and desktop entry. The
launcher claims that entry under Robot. Desktop uninstall removes both
files. The menu uses the existing Apps CLI for downloads, compatibility
checks, installation, and launch. The launcher test verifies the Robot row
and checks that it appears once. A stubbed CLI and Fuzzel verified selection,
requirements review, confirmation, and launch.
The launcher and Apps unit tests passed with the removal action. A test with
stubbed Fuzzel and terminal wrappers exercised the real Apps CLI against a
temporary installation and verified cancellation, removal of every release of
the selected app, and the empty-list notification.
The installed launcher on Thor lists Corebrum Apps under Robot and finds it
from the root search.

Corebrum Apps and Corebrum Skills use the launcher chooser interface for
their action rows. Right enters either submenu and Left returns to Robot.
The standalone helpers still open Fuzzel when called directly.
