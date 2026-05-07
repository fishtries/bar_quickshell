from __future__ import annotations

from pathlib import Path

from aside.plugins import clear_cache, load_tools, run_tool
from aside.tools import web_search


class _FakeResponse:
    def __init__(self, html: str) -> None:
        self._html = html

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        return None

    def read(self) -> bytes:
        return self._html.encode("utf-8")


_HTML = """
<html>
  <body>
    <a class="result-link" href="/l/?uddg=https%3A%2F%2Fexample.com%2Fone">First result</a>
    <td class="result-snippet">First snippet with current info.</td>
    <a class="result-link" href="https://example.com/two">Second result</a>
    <td class="result-snippet">Second snippet.</td>
  </body>
</html>
"""


def test_loads_web_search_tool():
    clear_cache()
    tools = load_tools([Path(web_search.__file__).parent])
    names = {tool["function"]["name"] for tool in tools}
    assert "web_search" in names
    clear_cache()


def test_web_search_parses_duckduckgo_lite(monkeypatch):
    monkeypatch.setattr(
        web_search.urllib.request,
        "urlopen",
        lambda req, timeout: _FakeResponse(_HTML),
    )

    result = web_search.run("aside assistant", max_results=1)

    assert "Search results for: aside assistant" in result
    assert "First result" in result
    assert "https://example.com/one" in result
    assert "Second result" not in result


def test_web_search_validates_empty_query():
    assert web_search.run("   ").startswith("Error:")


def test_web_search_reports_network_errors(monkeypatch):
    def fail(req, timeout):
        raise OSError("offline")

    monkeypatch.setattr(web_search.urllib.request, "urlopen", fail)

    assert web_search.run("news") == "Search failed: offline"


def test_run_tool_executes_builtin_web_search(monkeypatch):
    clear_cache()
    monkeypatch.setattr(
        web_search.urllib.request,
        "urlopen",
        lambda req, timeout: _FakeResponse(_HTML),
    )

    result = run_tool(
        "web_search",
        {"query": "python", "max_results": 2},
        [Path(web_search.__file__).parent],
    )

    assert "First result" in result
    assert "Second result" in result
    clear_cache()
