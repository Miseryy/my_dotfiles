# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

if [[ "$TERM" == "linux" ]]; then
    ZSH_THEME=""
else
    ZSH_THEME="powerlevel10k/powerlevel10k"
fi
# =================================================================

# プラグイン設定などはそのままでOK
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

case ":${PATH}:" in
    *:"$HOME/.cargo/bin":*)
        ;;
    *)
        # Prepending path in case a system-installed rustc needs to be overridden
        export PATH="$HOME/.cargo/bin:$PATH"
        ;;
esac

export PATH=~/.npm-global/bin:$PATH
export PATH=$PATH:$HOME/.roswell/bin/
export PAGER=less
alias tenki='wthrr -f d'
alias emacs='emacs -nw'

if [ -f ~/.zshrc.local ]; then
    source ~/.zshrc.local
fi

if [[ "$TERM" == "linux" ]]; then
    # --------- TTY -------------------
    # シンプルなプロンプト設定
    PROMPT='%F{green}%n@%m%f %F{blue}%~%f %# '
    RPROMPT=''

    # アイコン無効化
    alias ls='ls --color=auto'
    alias ll='ls -l --color=auto'
    alias la='ls -la --color=auto'

else
    # ------ GUI 用の設定 -------------

    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
    alias vim='nvim'
    alias pbcopy='xclip -selection clipboard'
    alias pbpaste='xclip -selection clipboard -o'

    # Python環境
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init - zsh)"
    
    # p10k の設定ファイル読み込みは必要なので残す
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi
