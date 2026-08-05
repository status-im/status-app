package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
)

var qrcExtensions = map[string]bool{
	".qml":  true,
	".js":   true,
	".svg":  true,
	".png":  true,
	".ico":  true,
	".icns": true,
	".mp3":  true,
	".wav":  true,
	".otf":  true,
	".ttf":  true,
	".webm": true,
	".qm":   true,
	".txt":  true,
	".gif":  true,
	".json": true,
	".mdwn": true,
	".html": true,
}

var skippedDirs = map[string]bool{
	"vendor":       true,
	"tests":        true,
	"StatusQ":      true,
	"node_modules": true,
	"build":        true,
}

// Scripts injected into web pages (WebEngine/WKWebView), never loaded by the QML
// engine. They are written for a browser JS engine and use syntax qmlcachegen
// cannot parse (async/await, optional catch binding), so they are emitted into a
// separate .qrc that the build excludes from the Qt Quick Compiler.
const webScriptsDir = "app/AppLayouts/Browser/provider/js"

type qrcWriter struct {
	file  *os.File
	count int
}

func newQrcWriter(name string) *qrcWriter {
	f, err := os.Create(name)
	if err != nil {
		log.Fatalf("Failed creating qrc file: %s", err)
	}
	f.WriteString("<!DOCTYPE RCC>\n")
	f.WriteString("<RCC version=\"1.0\">\n")
	f.WriteString("  <qresource>\n")
	return &qrcWriter{file: f}
}

func (w *qrcWriter) add(path string) {
	w.count++
	w.file.WriteString("      <file>" + path + "</file>\n")
}

func (w *qrcWriter) close() {
	w.file.WriteString("  </qresource>\n")
	w.file.WriteString("</RCC>")
	w.file.Close()
}

func main() {
	sourceDirName := flag.String("source", "", "source dir containing ui files")
	qrcFileName := flag.String("output", "resources.qrc", "output filename")
	webScriptsQrcFileName := flag.String("webscripts-output", "", "output filename for browser user scripts; when empty they go into -output")
	flag.Parse()
	if flag.NFlag() == 0 {
		flag.Usage()
		return
	}

	resources := newQrcWriter(*qrcFileName)
	defer resources.close()

	webScripts := resources
	if *webScriptsQrcFileName != "" {
		webScripts = newQrcWriter(*webScriptsQrcFileName)
		defer webScripts.close()
	}

	err := filepath.Walk(*sourceDirName,
		func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if info.IsDir() && skippedDirs[info.Name()] {
				return filepath.SkipDir
			}
			if !info.IsDir() {
				ext := filepath.Ext(path)
				base := filepath.Base(path)
				if qrcExtensions[ext] || base == "qmldir" {
					fixedPath := strings.ReplaceAll(path, "\\", "/")
					fixedPath = "./" + strings.TrimPrefix(fixedPath, *sourceDirName)
					if strings.Contains(fixedPath, webScriptsDir) {
						webScripts.add(fixedPath)
					} else {
						resources.add(fixedPath)
					}
				}
			}
			return nil
		})
	if err != nil {
		log.Fatalf("Failed walking %s: %s", *sourceDirName, err)
	}

	if webScripts != resources {
		fmt.Printf("%d resources added, %d web scripts added\n", resources.count, webScripts.count)
	} else {
		fmt.Printf("%d resources added\n", resources.count)
	}
}
