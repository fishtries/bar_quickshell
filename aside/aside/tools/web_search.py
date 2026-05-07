from __future__ import annotations

import urllib.parse
import urllib.request
from html.parser import HTMLParser

TOOL_SPEC = {
    "name": "web_search",
    "description": (
        "Search the internet for current information. Use this when the user asks "
        "about recent events, current versions, prices, news, facts that may have "
        "changed, or anything that requires fresh web results. Returns titles, URLs, "
        "and snippets for the top results."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "The internet search query.",
            },
            "max_results": {
                "type": "integer",
                "description": "Maximum number of search results to return, from 1 to 10. Default is 5.",
            },
        },
        "required": ["query"],
    },
}

_LITE_URL = "https://lite.duckduckgo.com/lite/"
_HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; Aside/0.6)"}


class _LiteParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.results: list[dict[str, str]] = []
        self._in_link = False
        self._in_snippet = False
        self._cur: dict[str, str] = {}
        self._text = ""

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr = dict(attrs)
        if tag == "a" and attr.get("class") == "result-link":
            self._in_link = True
            self._cur = {"url": _clean_url(attr.get("href") or ""), "title": "", "snippet": ""}
            self._text = ""
        elif tag == "td" and attr.get("class") == "result-snippet":
            self._in_snippet = True
            self._text = ""

    def handle_endtag(self, tag: str) -> None:
        if tag == "a" and self._in_link:
            self._in_link = False
            self._cur["title"] = " ".join(self._text.split())
        elif tag == "td" and self._in_snippet:
            self._in_snippet = False
            self._cur["snippet"] = " ".join(self._text.split())
            if self._cur.get("url") and self._cur.get("title"):
                self.results.append(self._cur)
            self._cur = {}

    def handle_data(self, data: str) -> None:
        if self._in_link or self._in_snippet:
            self._text += data


def _clean_url(url: str) -> str:
    if not url:
        return ""
    parsed = urllib.parse.urlparse(url)
    query = urllib.parse.parse_qs(parsed.query)
    if "uddg" in query and query["uddg"]:
        return query["uddg"][0]
    return url


def _coerce_max_results(value: int | str | None) -> int:
    try:
        count = int(value or 5)
    except (TypeError, ValueError):
        count = 5
    return max(1, min(count, 10))


def _search(query: str, max_results: int) -> list[dict[str, str]]:
    data = urllib.parse.urlencode({"q": query}).encode("utf-8")
    req = urllib.request.Request(_LITE_URL, data=data, headers=_HEADERS)
    with urllib.request.urlopen(req, timeout=10) as resp:
        html = resp.read().decode("utf-8", errors="replace")
    parser = _LiteParser()
    parser.feed(html)
    return parser.results[:max_results]


def run(query: str, max_results: int | str | None = 5) -> str:
    query = (query or "").strip()
    if not query:
        return "Error: query is required."

    count = _coerce_max_results(max_results)
    try:
        results = _search(query, count)
    except Exception as exc:
        return f"Search failed: {exc}"

    if not results:
        return "No results found."

    lines = [f"Search results for: {query}", ""]
    for idx, item in enumerate(results, 1):
        lines.append(f"{idx}. {item['title']}")
        lines.append(item["url"])
        if item.get("snippet"):
            lines.append(item["snippet"])
        lines.append("")
    return "\n".join(lines).strip()
