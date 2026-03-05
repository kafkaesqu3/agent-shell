# TODO

## Search MCP Server

Compare and select a web search MCP server to add to the container config:

| Tool | Type | Notes |
|------|------|-------|
| [Exa](https://exa.ai) | AI-native search API | Used by TrailOfBits config, semantic search, API key required |
| [Tavily](https://tavily.com) | AI search API | Built for agents, structured results, API key required |
| [Firecrawl](https://firecrawl.dev) | Web scraping + search | Crawl/scrape focus, can extract structured data |
| [Brave Search](https://brave.com/search/api/) | Traditional search API | Already in container config, privacy-focused |
| [SearXNG](https://github.com/searxng/searxng) | Self-hosted metasearch | No API key, self-hosted, aggregates multiple engines |

Decision criteria:
- Quality of results for code/documentation queries
- MCP server availability and maturity
- Cost and rate limits
- Whether it adds value over Brave Search (already configured)
- Whether it justifies the CLAUDE.md instruction to prefer it over WebSearch
