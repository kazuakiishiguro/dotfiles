# dotfiles

* this is my dotfiles. i use `emacs` as an editor
* i manage them with [GNU Stow](https://www.gnu.org/software/stow/).

## setup

``` bash
$ ./init.sh
```

### ChatGPT API key

1. Create `~/emacs.d/.env.el`
2. Set [OpenAI's API keys](https://platform.openai.com/account/api-keys) for [chatgpt-shell](https://github.com/xenodium/chatgpt-shell) emacs package.

`.env.el`
```emacs-lisp
(setq chatgpt-shell-openai-key "{YOUR_API_KEY}")
```
