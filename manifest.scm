(use-modules (guix build-system copy)
             (guix download)
             (guix packages))

(define amp-platform
  "linux-arm64")
;; Replace VERSION with actual version from cli-version.txt
;; Get from https://static.ampcode.com/cli/cli-version.txt
(define amp-version
  "0.0.1779713994-g4ef406")

(define amp-cli
  (package
    (name "amp-cli")
    (version amp-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://static.ampcode.com/cli/" amp-version
                           "/amp-" amp-platform))
       (file-name "amp")
       ;; Calculate via `guix download https://static.ampcode.com/cli/$(curl -s https://static.ampcode.com/cli/cli-version.txt)/amp-linux-arm64`
       (sha256
        (base32 "1adk0sdj8yikazbxrc6snhb82xzgzksnsa3bnn5mx0x3djl74b6r"))))
    (build-system copy-build-system)
    (arguments
     `(#:install-plan '(("amp" "bin/amp"))
       #:validate-runpath? #f
       ;; Disable strip-binaries phase.
       ;; strip phase removing the embedded JavaScript payload from the Bun-compiled standalone executable.
       ;; A Bun standalone executable embeds its app payload in the ELF binary — typically in a
       ;; non-allocated section (or appended region) that strip considers discardable "unneeded" data.
       #:strip-binaries? #f
       #:phases (modify-phases %standard-phases
                  (add-after 'install 'make-executable
                    (lambda* (#:key outputs #:allow-other-keys)
                      (chmod (string-append (assoc-ref outputs "out")
                                            "/bin/amp") #o755) #t)))))
    (synopsis "Amp CLI - The frontier coding agent")
    (description
     "Amp is the frontier coding agent built for leading models, and what comes next.")
    (home-page "https://ampcode.com")
    (license #f)))

;; Convert package name to package object.
(define predefined-packages
  (map specification->package
       (list "bash"
             "busybox"
             "gcc-toolchain" ;linker for bun.
             "git"
             "nss-certs" ;trusted CA store.
             "zsh")))

(packages->manifest (append (list amp-cli) predefined-packages))
