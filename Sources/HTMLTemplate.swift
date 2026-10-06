import Foundation

enum CheckIcon {
    static let grid: CGFloat = 24
    static let points: [CGPoint] = [CGPoint(x: 20, y: 6), CGPoint(x: 9, y: 17), CGPoint(x: 4, y: 12)]
    static let strokeWidth: CGFloat = 2.5
    static let confirmSeconds: TimeInterval = 1.6

    static var svg: String {
        let pts = points.map { "\(Int($0.x)) \(Int($0.y))" }.joined(separator: " ")
        return "<svg viewBox=\"0 0 \(Int(grid)) \(Int(grid))\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"\(strokeWidth)\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"\(pts)\"></polyline></svg>"
    }
}

enum CopyIcon {
    static let grid: CGFloat = 24
    static let strokeWidth: CGFloat = 2
    static let radius: CGFloat = 2.5
    static let front = CGRect(x: 8, y: 8, width: 13, height: 13)
    static let backCorners: [CGPoint] = [CGPoint(x: 16, y: 8), CGPoint(x: 16, y: 3), CGPoint(x: 3, y: 3),
                                         CGPoint(x: 3, y: 16), CGPoint(x: 8, y: 16)]

    static var svg: String {
        let c = backCorners.map { "\(n($0.x)) \(n($0.y))" }
        let r = n(radius)
        let back = "M\(c[0])V\(n(backCorners[1].y + radius))A\(r) \(r) 0 0 0 \(n(backCorners[1].x - radius)) \(n(backCorners[1].y))"
            + "H\(n(backCorners[2].x + radius))A\(r) \(r) 0 0 0 \(n(backCorners[2].x)) \(n(backCorners[2].y + radius))"
            + "V\(n(backCorners[3].y - radius))A\(r) \(r) 0 0 0 \(n(backCorners[3].x + radius)) \(n(backCorners[3].y))H\(n(backCorners[4].x))"
        return "<svg viewBox=\"0 0 \(Int(grid)) \(Int(grid))\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"\(n(strokeWidth))\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"\(n(front.minX))\" y=\"\(n(front.minY))\" width=\"\(n(front.width))\" height=\"\(n(front.height))\" rx=\"\(r)\"></rect><path d=\"\(back)\"></path></svg>"
    }

    private static func n(_ v: CGFloat) -> String {
        v == v.rounded() ? String(Int(v)) : String(Double(v))
    }
}

enum HTMLTemplate {

    private static let mermaidJS: String? = {
        guard let url = Bundle.main.url(forResource: "mermaid.min", withExtension: "js"),
              let js = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return js
    }()

    // KaTeX's stylesheet embeds its fonts as data: URIs, which the CSP's font-src allows.
    private static let katexJS: String? = {
        guard let url = Bundle.main.url(forResource: "katex.min", withExtension: "js"),
              let js = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return js
    }()

    private static let katexCSS: String? = {
        guard let url = Bundle.main.url(forResource: "katex.min", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return css
    }()

    static func wrap(body: String, hasMermaid: Bool = false, hasMath: Bool = false,
                     compact: Bool = false, isDark: Bool = false,
                     palette customPalette: ReaderThemePalette? = nil,
                     typography: ReaderTypography = .default) -> String {
        let palette = customPalette ?? ReaderThemeCatalog.palette(
            for: .default,
            scheme: isDark ? .dark : .light
        )
        let rendersDark = palette.scheme.isDark
        let fontSize = compact ? "14px" : "16px"
        // Extra clearance for the floating header; Quick Look (compact) has none.
        let topPadding = compact ? "32px" : "64px"
        // Blur veil under the header; a fixed element would repeat on every printed page.
        let headerBlur = compact ? "" : """
        body::before {
            content: "";
            position: fixed;
            top: 0; left: 0; right: 0;
            height: 64px;
            pointer-events: none;
            z-index: 10;
            -webkit-backdrop-filter: blur(10px);
            backdrop-filter: blur(10px);
            -webkit-mask-image: linear-gradient(to bottom, black 30%, transparent 100%);
            mask-image: linear-gradient(to bottom, black 30%, transparent 100%);
        }
        @media print { body::before { display: none; } }
        """
        let tableOfContentsCSS = compact ? "" : """
        /* Table of contents. It lives inside the rendered page so a normal
           full-page live reload rebuilds it from the new heading DOM. */
        #rd-table-of-contents {
            position: fixed;
            z-index: 20;
            top: 58px;
            /* The page viewport ends before its 10px scrollbar gutter. Together,
               2px here and that gutter match the native header's 12pt edge inset. */
            right: 2px;
            bottom: 12px;
            width: 260px;
            display: flex;
            flex-direction: column;
            color: var(--text);
            background: var(--bg);
            border: 1px solid var(--hairline);
            /* The native action panel is a 34pt-high Capsule: 34 / 2 = 17. */
            border-radius: 17px;
            box-shadow: 0 8px 28px rgba(0, 0, 0, 0.16);
            opacity: 0;
            visibility: hidden;
            pointer-events: none;
            transform: translateX(12px);
            transition: opacity 0.16s ease, transform 0.16s ease, visibility 0.16s;
            overflow: hidden;
        }
        body.rd-table-of-contents-open #rd-table-of-contents {
            opacity: 1;
            visibility: visible;
            pointer-events: auto;
            transform: translateX(0);
        }
        .rd-toc-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex: 0 0 auto;
            min-height: 42px;
            padding: 6px 8px 6px 14px;
            border-bottom: 1px solid var(--hairline);
            font-family: var(--ui-font-family);
            font-size: var(--ui-font-size);
            font-weight: var(--ui-font-weight);
            letter-spacing: 0.02em;
            color: var(--muted);
            -webkit-user-select: none;
            user-select: none;
        }
        .rd-toc-close {
            width: 28px;
            height: 28px;
            padding: 0;
            border: 0;
            border-radius: 6px;
            color: var(--muted);
            background: transparent;
            font: inherit;
            font-size: 17px;
            line-height: 28px;
            cursor: default;
        }
        .rd-toc-close:hover,
        .rd-toc-close:focus-visible {
            color: var(--text);
            background: var(--code-bg);
            outline: none;
        }
        .rd-toc-list {
            flex: 1 1 auto;
            min-height: 0;
            padding: 8px;
            overflow-x: hidden;
            overflow-y: auto;
        }
        .rd-toc-link {
            display: block;
            padding-top: 5px;
            padding-right: 9px;
            padding-bottom: 5px;
            border-radius: 6px;
            color: var(--muted);
            font-family: var(--ui-font-family);
            font-size: var(--ui-font-size);
            font-weight: var(--ui-font-weight);
            line-height: 1.35;
            text-decoration: none;
            text-overflow: ellipsis;
            white-space: nowrap;
            overflow: hidden;
            cursor: default;
        }
        .rd-toc-link:hover,
        .rd-toc-link:focus-visible {
            color: var(--text);
            background: var(--code-bg);
            outline: none;
            text-decoration: none;
        }
        .rd-toc-link.rd-toc-active {
            color: var(--link);
            background: var(--code-bg);
            font-weight: 600;
        }
        @media (min-width: 720px) {
            body.rd-table-of-contents-open {
                padding-right: calc(clamp(28px, 5vw, 96px) + 280px);
            }
        }
        @media (max-width: 640px) {
            #rd-table-of-contents {
                left: 12px;
                width: auto;
            }
        }
        @media print {
            #rd-table-of-contents { display: none !important; }
        }
        """
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src file: data: https: http:; font-src \(hasMath ? "data:" : "'none'"); connect-src 'none'; form-action 'none';">
        <meta name="color-scheme" content="\(rendersDark ? "dark" : "light")">
        <style>
        :root {
            color-scheme: \(rendersDark ? "dark" : "light");
            \(palette.cssVariables)
            \(typography.cssVariables)
        }

        * {
            box-sizing: border-box;
        }

        html {
            scroll-behavior: smooth;
        }

        \(headerBlur)
        \(tableOfContentsCSS)

        body {
            font-family: var(--body-font-family), "Apple Color Emoji";
            font-size: \(compact ? fontSize : "var(--body-font-size)");
            font-weight: var(--body-font-weight);
            line-height: 1.6;
            color: var(--text);
            background: var(--bg);
            margin: 0;
            padding: \(topPadding) clamp(28px, 5vw, 96px) 32px clamp(28px, 5vw, 96px);
            word-wrap: break-word;
            overflow-x: hidden;
            -webkit-font-smoothing: antialiased;
            text-rendering: optimizeLegibility;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }

        /* Sizes follow a 1.25 modular scale; em margins scale with the heading. */
        h1, h2, h3, h4, h5, h6 {
            margin: 1.6em 0 0.6em;
            font-weight: 600;
            line-height: 1.25;
            /* anchor targets clear the floating header */
            scroll-margin-top: 56px;
            position: relative;
        }
        .rd-fold {
            position: absolute;
            left: -1.15rem;
            top: 0.42em;
            width: 14px;
            height: 14px;
            color: var(--muted);
            opacity: 0;
            cursor: default;
            transition: opacity 0.15s ease, transform 0.15s ease;
            -webkit-user-select: none;
            user-select: none;
        }
        .rd-fold svg { width: 100%; height: 100%; display: block; }
        h1:hover > .rd-fold, h2:hover > .rd-fold, h3:hover > .rd-fold,
        h4:hover > .rd-fold, h5:hover > .rd-fold, h6:hover > .rd-fold { opacity: 0.3; }
        .rd-fold:hover { opacity: 0.7; }
        .rd-collapsed > .rd-fold { transform: rotate(-90deg); opacity: 0.28; }
        .rd-fold-hidden { display: none !important; }
        @media print {
            .rd-fold { display: none; }
            .rd-fold-hidden { display: revert !important; }
        }
        h1 { font-size: 1.95em; letter-spacing: -0.015em; }
        h2 { font-size: 1.56em; letter-spacing: -0.01em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: var(--muted); }

        /* body padding already clears the header */
        body > :first-child { margin-top: 0; }

        p {
            margin-top: 0;
            margin-bottom: 1em;
        }

        a {
            color: var(--link);
            text-decoration: underline;
            text-decoration-color: var(--link-underline);
            text-decoration-thickness: 1px;
            text-underline-offset: 2px;
        }

        a:hover {
            text-decoration-color: var(--link);
        }

        code {
            font-family: var(--code-font-family);
            font-size: var(--code-font-size);
            font-weight: var(--code-font-weight);
            padding: 0.15em 0.35em;
            background: var(--code-bg);
            border-radius: 4px;
        }

        pre {
            padding: 16px 20px;
            overflow: auto;
            font-family: var(--code-font-family);
            font-size: var(--code-font-size);
            font-weight: var(--code-font-weight);
            line-height: 1.55;
            background: var(--code-bg);
            border-radius: 8px;
            margin: 1.25em 0;
            max-width: 100%;
            white-space: pre-wrap;
            overflow-wrap: break-word;
            /* 2ch sits off the 4-space code grid, so a wrapped continuation can't read as new code. */
            text-indent: 2ch hanging each-line;
        }

        pre code, pre code.hljs {
            padding: 0;
            background: transparent;
            border-radius: 0;
            font-size: 100%;
        }

        /* The wrapper doesn't scroll with the <pre>, so the copy button stays pinned. */
        .rd-codeblock {
            position: relative;
        }

        .rd-copy-btn {
            position: absolute;
            top: 8px;
            right: 10px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 28px;
            height: 28px;
            padding: 0;
            color: var(--muted);
            background: var(--code-bg);
            border: 1px solid var(--border);
            border-radius: 6px;
            cursor: default;
            opacity: 0;
            transition: opacity 0.15s ease, color 0.15s ease, border-color 0.15s ease;
            -webkit-user-select: none;
            user-select: none;
        }

        .rd-codeblock:hover .rd-copy-btn,
        .rd-copy-btn:focus-visible {
            opacity: 1;
        }

        .rd-copy-btn:hover {
            color: var(--text);
            border-color: var(--muted);
        }

        .rd-copy-btn.rd-copied {
            opacity: 1;
            color: var(--success);
            border-color: var(--success);
        }

        .rd-copy-btn svg {
            display: block;
            width: 16px;
            height: 16px;
        }

        blockquote {
            margin: 0 0 1em 0;
            padding: 0 1em;
            color: var(--muted);
            border-left: 3px solid var(--blockquote-border);
        }

        ul, ol {
            margin-top: 0;
            margin-bottom: 1em;
            padding-left: 2em;
        }

        li + li {
            margin-top: 0.35em;
        }

        hr {
            height: 0;
            padding: 0;
            margin: 2em 0;
            border: 0;
            border-top: 1px solid var(--border);
        }

        img {
            max-width: 100%;
            height: auto;
            border-radius: 6px;
        }

        del {
            opacity: 0.6;
        }

        table {
            border-collapse: collapse;
            border-spacing: 0;
            margin: 0 0 1em 0;
            width: auto;
            max-width: 100%;
            overflow: auto;
            display: block;
            font-size: 0.95em;
        }

        th, td {
            padding: 8px 14px;
            border: 1px solid var(--border);
        }

        th {
            font-weight: 600;
            background: var(--table-header);
            text-align: left;
        }

        tr:nth-child(even) {
            background: var(--table-stripe);
        }

        ul.task-list {
            list-style: none;
            padding-left: 0;
            margin-bottom: 16px;
        }

        li.task-item {
            position: relative;
            padding-left: 1.55em;
            margin-top: 0.15em;
            margin-bottom: 0.15em;
            line-height: 1.5;
            overflow: hidden;
        }

        li.task-item input[type="checkbox"] {
            -webkit-appearance: none;
            appearance: none;
            position: absolute;
            left: 0;
            top: 0.25em;
            width: 16px;
            height: 16px;
            border: 1.5px solid var(--border);
            border-radius: 4px;
            background: var(--bg);
            cursor: default;
            margin: 0;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }

        li.task-item input[type="checkbox"]:checked {
            background-color: var(--link);
            border-color: var(--link);
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath fill='none' stroke='%23fff' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round' d='M3.5 8.5 6.7 11.7 12.5 4.8'/%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: center;
            background-size: 100% 100%;
        }
        pre.mermaid {
            background: transparent;
            padding: 0;
            text-align: center;
            /* pre's hanging indent pushes wrapped diagram labels past their foreignObject */
            text-indent: 0;
        }
        .mermaid svg {
            max-width: 100%;
            height: auto;
        }
        /* Mermaid boxes flowchart labels in a fixed-width foreignObject; wrapping lets it grow the node instead of clipping. */
        pre.mermaid svg[aria-roledescription="flowchart-v2"] .nodeLabel p {
            white-space: normal;
            overflow-wrap: anywhere;
        }
        /* Display math scrolls horizontally so a wide equation never widens the page. */
        .rd-math-display {
            display: block;
            margin: 1.25em 0;
            text-align: center;
            overflow-x: auto;
            overflow-y: hidden;
        }
        .rd-math-inline { display: inline; }
        /* .rd-math-display owns the vertical margin */
        .katex-display { margin: 0 !important; }
        .rd-math-error,
        .katex-error {
            color: var(--danger);
            font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
            font-size: 0.875em;
            white-space: pre-wrap;
        }
        /* Autohide scrollbar: invisible by default, fades in while scrolling.
           Thin Bear-style: ~6px visible thumb (10px track, 2px transparent border). */
        ::-webkit-scrollbar {
            width: 10px;
            height: 10px;
            background: transparent;
        }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb {
            background: transparent;
            border-radius: 5px;
            border: 2px solid transparent;
            background-clip: content-box;
            transition: background-color 0.25s ease;
        }
        body.rd-scrolling::-webkit-scrollbar-thumb {
            background-color: var(--scrollbar-thumb);
            background-clip: content-box;
        }
        mark.rd-find {
            background: var(--find-bg);
            color: inherit;
            padding: 0;
            border-radius: 2px;
        }
        mark.rd-find-current {
            background: var(--find-current-bg);
            color: inherit;
            box-shadow: 0 0 0 2px var(--syntax-built-in);
        }
        \(SyntaxHighlight.css)
        /* Theme-aware overrides for the bundled Highlight.js token classes. */
        .hljs { color: var(--syntax-text); background: var(--code-bg); }
        .hljs-doctag, .hljs-keyword, .hljs-meta .hljs-keyword,
        .hljs-template-tag, .hljs-template-variable, .hljs-type,
        .hljs-variable.language_ { color: var(--syntax-keyword); }
        .hljs-title, .hljs-title.class_, .hljs-title.class_.inherited__,
        .hljs-title.function_ { color: var(--syntax-title); }
        .hljs-attr, .hljs-attribute, .hljs-literal, .hljs-meta, .hljs-number,
        .hljs-operator, .hljs-selector-attr, .hljs-selector-class,
        .hljs-selector-id, .hljs-variable { color: var(--syntax-literal); }
        .hljs-meta .hljs-string, .hljs-regexp, .hljs-string { color: var(--syntax-string); }
        .hljs-built_in, .hljs-symbol { color: var(--syntax-built-in); }
        .hljs-code, .hljs-comment, .hljs-formula { color: var(--syntax-comment); }
        .hljs-name, .hljs-quote, .hljs-selector-pseudo,
        .hljs-selector-tag { color: var(--syntax-tag); }
        .hljs-subst, .hljs-emphasis, .hljs-strong { color: var(--syntax-text); }
        .hljs-section { color: var(--link); font-weight: 700; }
        .hljs-bullet { color: var(--syntax-built-in); }
        .hljs-emphasis { font-style: italic; }
        .hljs-strong { font-weight: 700; }
        .hljs-addition { color: var(--success); background-color: var(--syntax-addition-bg); }
        .hljs-deletion { color: var(--danger); background-color: var(--syntax-deletion-bg); }
        @media print {
            body {
                padding: 0;
                margin: 0;
                font-size: 11pt;
                line-height: 1.5;
            }
            h1 { font-size: 18pt; }
            h2 { font-size: 15pt; }
            h3 { font-size: 13pt; }
            pre, pre code, .hljs {
                white-space: pre-wrap;
                word-wrap: break-word;
                font-size: 9pt;
            }
            pre, blockquote, table, img { page-break-inside: avoid; }
            h1, h2, h3, h4 { page-break-after: avoid; }
            .rd-copy-btn { display: none; }
        }
        </style>
        </head>
        <body data-rd-theme="\(rendersDark ? "dark" : "light")" data-rd-theme-family="\(palette.family.rawValue)">
        \(body)
        <script>\(SyntaxHighlight.js)</script>
        <script>
        hljs.configure({ languages: [
            'bash', 'c', 'cpp', 'css', 'diff', 'go', 'java', 'javascript',
            'json', 'kotlin', 'python', 'ruby', 'rust', 'shell', 'sql',
            'swift', 'typescript', 'xml', 'yaml'
        ]});
        hljs.highlightAll();
        </script>
        <script>
        // Runs after highlightAll; Mermaid <pre>s have no <code> child, so `pre > code` skips them.
        (function() {
            const COPY_ICON = '\(CopyIcon.svg)';
            const CHECK_ICON = '\(CheckIcon.svg)';

            function legacyCopy(text) {
                const ta = document.createElement('textarea');
                ta.value = text;
                ta.setAttribute('readonly', '');
                ta.style.position = 'fixed';
                ta.style.top = '0';
                ta.style.left = '0';
                ta.style.opacity = '0';
                document.body.appendChild(ta);
                ta.select();
                let ok = false;
                try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
                document.body.removeChild(ta);
                return ok;
            }

            function showCopied(btn) {
                // No-op unless the host installed the handler.
                try { window.webkit.messageHandlers.rdUsage.postMessage('copy_code'); } catch (e) {}
                btn.classList.add('rd-copied');
                btn.innerHTML = CHECK_ICON;
                btn.setAttribute('aria-label', 'Copied');
                clearTimeout(btn._rdTimer);
                btn._rdTimer = setTimeout(function() {
                    btn.classList.remove('rd-copied');
                    btn.innerHTML = COPY_ICON;
                    btn.setAttribute('aria-label', 'Copy code');
                }, \(Int(CheckIcon.confirmSeconds * 1000)));
            }

            function copyCode(code, btn) {
                const text = code.textContent;
                // execCommand is the reliable path under loadHTMLString.
                if (navigator.clipboard && navigator.clipboard.writeText) {
                    navigator.clipboard.writeText(text).then(
                        function() { showCopied(btn); },
                        function() { if (legacyCopy(text)) showCopied(btn); }
                    );
                } else if (legacyCopy(text)) {
                    showCopied(btn);
                }
            }

            document.querySelectorAll('pre > code').forEach(function(code) {
                const pre = code.parentElement;
                const wrap = document.createElement('div');
                wrap.className = 'rd-codeblock';
                pre.parentNode.insertBefore(wrap, pre);
                wrap.appendChild(pre);

                const btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'rd-copy-btn';
                btn.setAttribute('aria-label', 'Copy code');
                btn.innerHTML = COPY_ICON;
                btn.addEventListener('click', function() { copyCode(code, btn); });
                wrap.appendChild(btn);
            });
        })();
        </script>
        <script>
        // Rewrites Cmd+C: WebKit's default serialization bakes computed styles into the paste.
        (function() {
            // Null prototype so inherited names can't pass the allowlist.
            var KEEP_ATTRS = Object.assign(Object.create(null),
                { href: 1, src: 1, alt: 1, title: 1, colspan: 1, rowspan: 1, start: 1 });
            // cloneContents() drops ancestors that fully contain the range, so a
            // selection inside one block would lose its block identity.
            var WRAP = /^(H[1-6]|P|PRE|CODE|BLOCKQUOTE|EM|STRONG|B|I|DEL|A)$/;
            var WRAP_TABLE = /^(TABLE|THEAD|TBODY|TR|TD|TH)$/;
            var WRAP_LIST = /^(LI|UL|OL)$/;
            var MONO = "font-family:'Courier New',monospace";

            function shouldWrap(node, content) {
                var tag = node.tagName;
                if (WRAP_TABLE.test(tag)) return content.querySelector('td, th') !== null;
                if (WRAP_LIST.test(tag)) return content.querySelector('li') !== null;
                return WRAP.test(tag);
            }

            function clean(root) {
                root.querySelectorAll('.rd-fold, .rd-fold-hidden, .rd-copy-btn, script, style, button').forEach(function(el) {
                    el.remove();
                });
                root.querySelectorAll('mark.rd-find, mark.rd-find-current').forEach(function(el) {
                    el.replaceWith(document.createTextNode(el.textContent));
                });
                // KaTeX's markup repeats the text across MathML and HTML layers.
                root.querySelectorAll('.rd-math').forEach(function(el) {
                    var display = el.classList.contains('rd-math-display');
                    var ann = el.querySelector('annotation[encoding="application/x-tex"]');
                    var tex = (ann ? ann.textContent : el.textContent).trim();
                    var out = document.createElement(display ? 'pre' : 'code');
                    out.textContent = display ? '$$' + tex + '$$' : '$' + tex + '$';
                    el.replaceWith(out);
                });
                // The rendered SVG doesn't survive an HTML paste.
                root.querySelectorAll('pre.mermaid').forEach(function(el) {
                    var out = document.createElement('pre');
                    out.textContent = el.getAttribute('data-rd-src') || el.textContent;
                    el.replaceWith(out);
                });
                root.querySelectorAll('svg').forEach(function(el) { el.remove(); });
                root.querySelectorAll('input[type="checkbox"]').forEach(function(el) {
                    el.replaceWith(document.createTextNode(el.checked ? '☑' : '☐'));
                });
                root.querySelectorAll('.rd-codeblock').forEach(function(el) {
                    var pre = el.querySelector('pre');
                    if (pre) { el.replaceWith(pre); } else { el.remove(); }
                });
                root.querySelectorAll('code').forEach(function(el) {
                    el.textContent = el.textContent;
                });
                root.querySelectorAll('*').forEach(function(el) {
                    for (var i = el.attributes.length - 1; i >= 0; i--) {
                        var name = el.attributes[i].name;
                        if (!KEEP_ATTRS[name]) el.removeAttribute(name);
                    }
                });
                root.querySelectorAll('pre, code').forEach(function(el) {
                    el.setAttribute('style', MONO);
                });
                // Removed siblings leave blank text nodes that paste as empty lines.
                Array.prototype.slice.call(root.childNodes).forEach(function(n) {
                    if (n.nodeType === 3 && !n.textContent.trim()) n.remove();
                });
            }

            window.__rdCopy = {
                htmlForSelection: function() {
                    var sel = window.getSelection();
                    if (!sel || sel.isCollapsed || sel.rangeCount === 0) return null;
                    var range = sel.getRangeAt(0);
                    var content = document.createElement('div');
                    content.appendChild(range.cloneContents());
                    var node = range.commonAncestorContainer;
                    if (node.nodeType !== 1) node = node.parentElement;
                    while (node && node !== document.body) {
                        if (shouldWrap(node, content)) {
                            var w = node.cloneNode(false);
                            while (content.firstChild) w.appendChild(content.firstChild);
                            content.appendChild(w);
                        }
                        node = node.parentElement;
                    }
                    clean(content);
                    return content.innerHTML;
                }
            };

            document.addEventListener('copy', function(e) {
                // The code-block button's execCommand fallback copies from a hidden textarea.
                if (e.target && (e.target.tagName === 'TEXTAREA' || e.target.tagName === 'INPUT')) return;
                if (!e.clipboardData) return;
                var html = window.__rdCopy.htmlForSelection();
                if (html === null) return;
                e.clipboardData.setData('text/html', html);
                e.clipboardData.setData('text/plain', window.getSelection().toString());
                e.preventDefault();
            });
        })();
        </script>
        <script>
        (function() {
            const MATCH = 'rd-find';
            const CURRENT = 'rd-find-current';
            let index = -1;
            function clear() {
                document.querySelectorAll('mark.' + MATCH).forEach(el => {
                    const t = document.createTextNode(el.textContent);
                    el.parentNode.replaceChild(t, el);
                });
                document.body.normalize();
                index = -1;
            }
            function escapeRe(s) { return s.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'); }
            function highlight() {
                document.querySelectorAll('mark.' + CURRENT).forEach(el => el.classList.remove(CURRENT));
                const all = document.querySelectorAll('mark.' + MATCH);
                if (index < 0 || index >= all.length) return;
                all[index].classList.add(CURRENT);
                all[index].scrollIntoView({ block: 'center', behavior: 'smooth' });
            }
            window.__rdFind = {
                search(q) {
                    clear();
                    if (!q) return { total: 0, current: 0 };
                    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
                        acceptNode: (n) => n.parentElement && n.parentElement.closest('script,style,[data-rd-search-exclude]') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT
                    });
                    const nodes = [];
                    let n;
                    while ((n = walker.nextNode())) nodes.push(n);
                    const re = new RegExp(escapeRe(q), 'gi');
                    let count = 0;
                    nodes.forEach(node => {
                        const text = node.nodeValue;
                        if (!re.test(text)) return;
                        re.lastIndex = 0;
                        const frag = document.createDocumentFragment();
                        let last = 0, m;
                        while ((m = re.exec(text)) !== null) {
                            if (m.index > last) frag.appendChild(document.createTextNode(text.slice(last, m.index)));
                            const mark = document.createElement('mark');
                            mark.className = MATCH;
                            mark.textContent = m[0];
                            frag.appendChild(mark);
                            last = m.index + m[0].length;
                            count++;
                        }
                        if (last < text.length) frag.appendChild(document.createTextNode(text.slice(last)));
                        node.parentNode.replaceChild(frag, node);
                    });
                    index = count > 0 ? 0 : -1;
                    highlight();
                    return { total: count, current: count > 0 ? 1 : 0 };
                },
                next() {
                    const all = document.querySelectorAll('mark.' + MATCH);
                    if (all.length === 0) return { total: 0, current: 0 };
                    index = (index + 1) % all.length;
                    highlight();
                    return { total: all.length, current: index + 1 };
                },
                prev() {
                    const all = document.querySelectorAll('mark.' + MATCH);
                    if (all.length === 0) return { total: 0, current: 0 };
                    index = (index - 1 + all.length) % all.length;
                    highlight();
                    return { total: all.length, current: index + 1 };
                },
                clear: clear
            };
        })();
        </script>
        \(compact ? "" : """
        <script>
        // Build the table of contents from the final heading DOM rather than
        // parsing Markdown a second time. This keeps setext headings, inline
        // formatting, duplicate slugs, and live reloads aligned with the renderer.
        (function() {
            var headings = Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6'))
                .filter(function(h) {
                    return !h.closest('[data-rd-search-exclude]')
                        && h.id && h.textContent.trim().length > 0;
                });
            var panel = null;
            var links = new Map();
            var updateScheduled = false;

            function visibleHeadings() {
                return headings.filter(function(h) { return h.getClientRects().length > 0; });
            }

            function capturePosition() {
                var candidates = visibleHeadings();
                var anchor = candidates.length > 0 ? candidates[0] : null;
                for (var i = 0; i < candidates.length; i++) {
                    if (candidates[i].getBoundingClientRect().top <= 80) {
                        anchor = candidates[i];
                    } else {
                        break;
                    }
                }
                return {
                    scrollY: window.scrollY,
                    anchorID: anchor ? anchor.id : null,
                    anchorOffset: anchor ? anchor.getBoundingClientRect().top : null
                };
            }

            function restorePosition(state) {
                var anchor = state.anchorID ? document.getElementById(state.anchorID) : null;
                if (anchor && typeof state.anchorOffset === 'number') {
                    window.scrollBy(0, anchor.getBoundingClientRect().top - state.anchorOffset);
                } else if (typeof state.scrollY === 'number') {
                    window.scrollTo(0, state.scrollY);
                }
            }

            function isVisible() {
                return !!panel && document.body.classList.contains('rd-table-of-contents-open');
            }

            function notifyHost() {
                var state = { available: headings.length > 0, visible: isVisible() };
                try {
                    window.webkit.messageHandlers.rdTableOfContents.postMessage(state);
                } catch (e) {}
            }

            function updateActive() {
                updateScheduled = false;
                var candidates = visibleHeadings();
                if (candidates.length === 0) return;
                var active = candidates[0];
                for (var i = 0; i < candidates.length; i++) {
                    if (candidates[i].getBoundingClientRect().top <= 96) {
                        active = candidates[i];
                    } else {
                        break;
                    }
                }
                if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2) {
                    active = candidates[candidates.length - 1];
                }
                links.forEach(function(link, heading) {
                    var selected = heading === active;
                    link.classList.toggle('rd-toc-active', selected);
                    if (selected) link.setAttribute('aria-current', 'location');
                    else link.removeAttribute('aria-current');
                });
            }

            function scheduleActiveUpdate() {
                if (updateScheduled) return;
                updateScheduled = true;
                window.requestAnimationFrame(updateActive);
            }

            function setVisible(visible, preservePosition) {
                if (!panel) return false;
                var position = preservePosition ? capturePosition() : null;
                document.body.classList.toggle('rd-table-of-contents-open', !!visible);
                panel.setAttribute('aria-hidden', visible ? 'false' : 'true');
                if (position) {
                    window.requestAnimationFrame(function() {
                        restorePosition(position);
                        scheduleActiveUpdate();
                    });
                }
                notifyHost();
                return isVisible();
            }

            window.__rdTableOfContents = {
                toggle: function() { return setVisible(!isVisible(), true); },
                capture: function() {
                    var state = capturePosition();
                    state.tableOfContentsVisible = isVisible();
                    return state;
                },
                restore: function(state) {
                    if (typeof state.tableOfContentsVisible === 'boolean') {
                        setVisible(state.tableOfContentsVisible, false);
                    }
                    // Two frames let the new page and its outline layout settle
                    // before the heading-relative reading position is restored.
                    window.requestAnimationFrame(function() {
                        window.requestAnimationFrame(function() {
                            restorePosition(state);
                            scheduleActiveUpdate();
                        });
                    });
                }
            };

            if (headings.length === 0) {
                notifyHost();
                return;
            }

            panel = document.createElement('aside');
            panel.id = 'rd-table-of-contents';
            panel.setAttribute('aria-label', 'Table of Contents');
            panel.setAttribute('aria-hidden', 'true');
            panel.setAttribute('data-rd-search-exclude', '');

            var header = document.createElement('div');
            header.className = 'rd-toc-header';
            var title = document.createElement('span');
            title.textContent = 'Contents';
            var close = document.createElement('button');
            close.type = 'button';
            close.className = 'rd-toc-close';
            close.setAttribute('aria-label', 'Close Table of Contents');
            close.textContent = '×';
            close.addEventListener('click', function() { setVisible(false, true); });
            header.appendChild(title);
            header.appendChild(close);
            panel.appendChild(header);

            var list = document.createElement('nav');
            list.className = 'rd-toc-list';
            var minimumLevel = headings.reduce(function(minimum, h) {
                return Math.min(minimum, Number(h.tagName.substring(1)));
            }, 6);

            headings.forEach(function(heading) {
                var link = document.createElement('a');
                var level = Number(heading.tagName.substring(1));
                link.className = 'rd-toc-link';
                link.href = '#' + encodeURIComponent(heading.id);
                link.textContent = heading.textContent.trim();
                link.title = link.textContent;
                link.style.paddingLeft = (9 + (level - minimumLevel) * 12) + 'px';
                link.addEventListener('click', function(event) {
                    event.preventDefault();
                    heading.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    if (window.innerWidth < 720) setVisible(false, false);
                });
                links.set(heading, link);
                list.appendChild(link);
            });
            panel.appendChild(list);
            document.body.appendChild(panel);

            window.addEventListener('scroll', scheduleActiveUpdate, { passive: true });
            setVisible(window.innerWidth >= 1000, false);
            updateActive();
        })();
        </script>
        """)
        <script>
        (function() {
            let timer;
            window.addEventListener('scroll', () => {
                document.body.classList.add('rd-scrolling');
                clearTimeout(timer);
                timer = setTimeout(() => document.body.classList.remove('rd-scrolling'), 700);
            }, { passive: true });
        })();
        </script>
        \(compact ? "" : """
        <script>
        // Headings are flat siblings, so a section runs to the next same-or-higher heading.
        (function() {
            var CH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>';
            function level(el) {
                return el && el.tagName && /^H[1-6]$/.test(el.tagName) ? +el.tagName.charAt(1) : 0;
            }
            document.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(function(h) {
                var lvl = level(h);
                var btn = document.createElement('span');
                btn.className = 'rd-fold';
                btn.innerHTML = CH;
                btn.setAttribute('role', 'button');
                btn.setAttribute('aria-label', 'Collapse section');
                h.insertBefore(btn, h.firstChild);
                btn.addEventListener('click', function(e) {
                    e.preventDefault();
                    e.stopPropagation();
                    var collapsed = h.classList.toggle('rd-collapsed');
                    btn.setAttribute('aria-label', collapsed ? 'Expand section' : 'Collapse section');
                    var el = h.nextElementSibling;
                    while (el) {
                        var l = level(el);
                        if (l > 0 && l <= lvl) break;
                        el.classList.toggle('rd-fold-hidden', collapsed);
                        el = el.nextElementSibling;
                    }
                });
            });
        })();
        </script>
        """)
        \(hasMath && katexJS != nil && katexCSS != nil ? """
        <style>\(katexCSS!)</style>
        <script>\(katexJS!)</script>
        <script>
        // Only renderer-emitted .rd-math nodes; a document-wide scan would eat stray `$` in prose and code.
        (function() {
            var nodes = document.querySelectorAll('.rd-math');
            for (var i = 0; i < nodes.length; i++) {
                var el = nodes[i];
                var display = el.classList.contains('rd-math-display');
                try {
                    katex.render(el.textContent, el, { displayMode: display, throwOnError: false });
                } catch (e) {
                    el.classList.add('rd-math-error');
                }
            }
        })();
        </script>
        """ : "")
        \(hasMermaid && mermaidJS != nil ? """
        <script>\(mermaidJS!)</script>
        <script>
        // Swift stamps data-rd-theme; matchMedia and getComputedStyle report stale values in WKWebView.
        const dark = document.body.dataset.rdTheme === 'dark';
        // Keep the named built-in theme as a rendering baseline, then replace
        // its semantic colors with the selected reader palette. Author-level
        // Mermaid `style` / `classDef` directives still take precedence.
        const themeVars = {
            background: '\(palette.background.cssHex)',
            textColor: '\(palette.text.cssHex)',
            primaryColor: '\(palette.surface.cssHex)',
            primaryTextColor: '\(palette.text.cssHex)',
            primaryBorderColor: '\(palette.border.cssHex)',
            secondaryColor: '\(palette.codeBackground.cssHex)',
            secondaryTextColor: '\(palette.text.cssHex)',
            secondaryBorderColor: '\(palette.border.cssHex)',
            tertiaryColor: '\(palette.tableHeader.cssHex)',
            tertiaryTextColor: '\(palette.text.cssHex)',
            tertiaryBorderColor: '\(palette.border.cssHex)',
            lineColor: '\(palette.muted.cssHex)',
            mainBkg: '\(palette.surface.cssHex)',
            secondBkg: '\(palette.codeBackground.cssHex)',
            nodeBorder: '\(palette.border.cssHex)',
            nodeTextColor: '\(palette.text.cssHex)',
            clusterBkg: '\(palette.tableHeader.cssHex)',
            clusterBorder: '\(palette.border.cssHex)',
            defaultLinkColor: '\(palette.muted.cssHex)',
            titleColor: '\(palette.text.cssHex)',
            edgeLabelBackground: '\(palette.background.cssHex)',
            actorBkg: '\(palette.surface.cssHex)',
            actorBorder: '\(palette.border.cssHex)',
            actorTextColor: '\(palette.text.cssHex)',
            actorLineColor: '\(palette.muted.cssHex)',
            signalColor: '\(palette.muted.cssHex)',
            signalTextColor: '\(palette.text.cssHex)',
            labelBoxBkgColor: '\(palette.codeBackground.cssHex)',
            labelBoxBorderColor: '\(palette.border.cssHex)',
            labelTextColor: '\(palette.text.cssHex)',
            loopTextColor: '\(palette.text.cssHex)',
            activationBorderColor: '\(palette.border.cssHex)',
            activationBkgColor: '\(palette.tableHeader.cssHex)',
            sequenceNumberColor: '\(palette.background.cssHex)',
            noteBkgColor: '\(palette.tableHeader.cssHex)',
            noteTextColor: '\(palette.text.cssHex)',
            noteBorderColor: '\(palette.border.cssHex)',
            labelColor: '\(palette.text.cssHex)',
            altBackground: '\(palette.codeBackground.cssHex)',
            classText: '\(palette.text.cssHex)',
            pie1: '\(palette.blue.cssHex)', pie2: '\(palette.orange.cssHex)', pie3: '\(palette.green.cssHex)',
            pie4: '\(palette.purple.cssHex)', pie5: '\(palette.red.cssHex)',
            pieTitleTextColor: '\(palette.text.cssHex)',
            pieSectionTextColor: '\(palette.background.cssHex)',
            pieLegendTextColor: '\(palette.text.cssHex)',
            pieStrokeColor: '\(palette.background.cssHex)',
            pieOuterStrokeColor: '\(palette.border.cssHex)',
            pieOpacity: '1'
        };
        document.querySelectorAll('pre.mermaid').forEach(function(el) {
            el.setAttribute('data-rd-src', el.textContent);
        });
        mermaid.initialize({
            startOnLoad: true,
            theme: dark ? 'dark' : 'default',
            themeVariables: themeVars,
            securityLevel: 'strict'
        });
        </script>
        """ : "")
        </body>
        </html>
        """
    }
}
