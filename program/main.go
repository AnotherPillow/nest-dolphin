package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/atotto/clipboard"
)

type FileInfo struct {
	AccessibleURL string `json:"accessibleURL"`
	CDNFileName   string `json:"cdnFileName"`
	DeletionURL   string `json:"deletionURL"`
	FileName      string `json:"fileName"`
	FileURL       string `json:"fileURL"`
}

func uploadFile(apiKey string, filePath string) ([]byte, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("open file: %w", err)
	}
	defer file.Close()

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	part, err := writer.CreateFormFile("files", filepath.Base(filePath))
	if err != nil {
		return nil, fmt.Errorf("create form file: %w", err)
	}

	if _, err = io.Copy(part, file); err != nil {
		return nil, fmt.Errorf("copy file data: %w", err)
	}

	if err = writer.Close(); err != nil {
		return nil, fmt.Errorf("close writer: %w", err)
	}

	req, err := http.NewRequest(
		http.MethodPost,
		"https://nest.rip/api/files/upload",
		&body,
	)
	if err != nil {
		return nil, fmt.Errorf("new request: %w", err)
	}

	req.Header.Set("User-Agent", "nest-dolphin/1.0.0")
	req.Header.Set("Authorization", apiKey)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf(
			"unexpected status %d: %s",
			resp.StatusCode,
			string(respBody),
		)
	}

	return respBody, nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Printf("no file specified!\n")
		os.Exit(1)
	}
	if len(os.Args) > 2 {
		fmt.Printf("too many arguments specified!\n")
		os.Exit(1)
	}

	fmt.Printf("uploading %s\n", os.Args[1])

	apiKeyBytes, e := os.ReadFile(os.ExpandEnv("$HOME/.nest-key"))
	if e != nil {
		fmt.Printf("No API Key found! Specify one in ~/.nest-key\n")
		os.Exit(1)
	}

	res, err := uploadFile(strings.TrimSpace(string(apiKeyBytes)), os.Args[1])
	if err != nil {
		fmt.Printf("Failed to upload, got error %v\n", err.Error())
		os.Exit(1)
	}

	var file FileInfo
	if err := json.Unmarshal(res, &file); err != nil {
		fmt.Printf("Failed to upload, got invalid response %v\n", err.Error())
		os.Exit(1)
	}

	fmt.Printf("file url: %s", file.AccessibleURL)
	// for some reason doesn't work natively on plasma, need wl-clipboard
	clipboard.WriteAll(file.AccessibleURL)
}
