(use-modules (guix packages))

(specifications->manifest (list "curl" "strace" ;print syscall when the program doesn't show detailed error.
                                ))
