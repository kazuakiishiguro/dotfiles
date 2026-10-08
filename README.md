# dotfiles

My dotfiles. I use `emacs` as an editor.

## Setup

One-liner for a fresh machine:

``` bash
bash <(curl -sL https://raw.githubusercontent.com/kazuakiishiguro/dotfiles/master/bootstrap.sh)
```

Or clone and run manually:

``` bash
git clone https://github.com/kazuakiishiguro/dotfiles.git
cd dotfiles
./init.sh
```

## Signed commits in remote Magit

`gpg-for-git` uses GnuPG's loopback mode when Magit runs inside an SSH
session. Magit then asks for the passphrase in the Emacs minibuffer, avoiding
terminal pinentry drawing over Emacs. Local commits keep the usual pinentry
dialog, and shell commits keep the usual GPG behavior.

After copying these changes to the remote dotfiles checkout, apply both modules:

```sh
stow -t ~ bin git
```

`~/.bin` must be in `PATH` (provided by this repository's `.shellrc`). This
requires GnuPG 2.1 or later and loopback pinentry to be allowed by the agent
(the default). If `~/.gnupg/gpg-agent.conf` contains `no-allow-loopback-pinentry`,
replace it with `allow-loopback-pinentry` and run `gpgconf --reload gpg-agent`.
