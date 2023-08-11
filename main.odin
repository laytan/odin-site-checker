package main

import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:net"

import "pkg/http"
import "pkg/http/client"

Config :: struct {
	to_check: []string,
	chat_id:  string,
	token:    string,
}

send_url: http.URL
conf: Config

@(init)
config :: proc() {
	context.allocator = context.temp_allocator

	check_raw, ok := os.lookup_env("SITES_TO_CHECK")
	if !ok do panic("SITES_TO_CHECK environment variable is not set")

	conf.chat_id, ok = os.lookup_env("TELEGRAM_CHAT_ID")
	if !ok do panic("TELEGRAM_CHAT_ID environment variable is not set")

	conf.token, ok = os.lookup_env("TELEGRAM_TOKEN")
	if !ok do panic("TELEGRAM_TOKEN environment variable is not set")

	conf.to_check = strings.split(check_raw, ", ")

	send_url.scheme = "https"
	send_url.host = "api.telegram.org"
	send_url.path = strings.concatenate([]string{"/bot", conf.token, "/sendMessage"})
	send_url.queries["chat_id"] = conf.chat_id

	return
}

main :: proc() {
	context.logger = log.create_console_logger()
	context.allocator = context.temp_allocator

	log.info("Checking sites...")
	defer log.info("Checked sites")

	for site in conf.to_check do check(site)
}

check :: proc(url: string) {
    log.infof("Checking: %s", url)

	response, err := client.get(url)
	if err != nil {
		notify_down(url, fmt.tprintf("%v", err))
		return
	}

	if !http.status_success(response.status) {
		body, _, err := client.response_body(&response)
		if err != nil {
			log.errorf("Error decoding body from site %s: %v", url, err)
			notify_down(url, fmt.tprintf("Status %d without body", response.status))
			return
		}

		notify_down(url, fmt.tprintf("Status %d with body: %v", response.status, body))
	}
}

notify_down :: proc(url: string, err: string) {
    txt := fmt.tprintf("%s is down, error was: %s", url, err)
	send_url.queries["text"] = net.percent_encode(txt)
	log.warn(txt)

	response, err := client.get(http.url_string(send_url))
	if err != nil do log.panicf("Could not send Telegram message: %v", err)
	if !http.status_success(response.status) {
		body, _, err := client.response_body(&response)
		if err != nil {
			log.panicf("Could not send telegram message, got status %d with body error: %v", response.status, err)
		}

		log.panicf("Could not send telegram message, got status %d with body: %v", response.status, body)
	}
}
