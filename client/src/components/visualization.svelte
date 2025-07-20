<script lang="ts">
  import * as d3 from "d3";
  import { onMount } from "svelte";

  let {
    url,
  }: {
    url: string;
  } = $props();

  let input = $state(url);
  let isRunning = $state(false);
  let visitedUrls = $state(new Set<string>());
  let pendingUrls = $state<string[]>([]);
  let nodes = $state<any[]>([]);
  let links = $state<any[]>([]);
  let svg: d3.Selection<SVGGElement, unknown, null, undefined>;
  let simulation: d3.Simulation<any, undefined>;
  let container: HTMLDivElement;
  let maxDepth = $state(500);
  let currentDepth = $state(0);
  let processedCount = $state(0);

  async function fetchHTML(link: string) {
    try {
      const res = await fetch("/api/get_html", {
        method: "POST",
        body: JSON.stringify({
          url: link,
        }),
      });
      const data = await res.json();
      return data["html"];
    } catch (error) {
      console.error(`Failed to fetch ${link}:`, error);
      return null;
    }
  }

  function extractLinks(html: string, baseUrl: string): string[] {
    if (!html) return [];

    const parser = new DOMParser();
    const doc = parser.parseFromString(html, "text/html");
    const linkElements = doc.querySelectorAll("a[href]");
    const links: string[] = [];

    linkElements.forEach((link) => {
      const href = link.getAttribute("href");
      if (href) {
        try {
          const absoluteUrl = new URL(href, baseUrl);
          // Only include HTTP/HTTPS links and avoid fragments
          if (
            absoluteUrl.protocol === "http:" ||
            absoluteUrl.protocol === "https:"
          ) {
            const cleanUrl = absoluteUrl.origin + absoluteUrl.pathname;
            if (!visitedUrls.has(cleanUrl)) {
              links.push(cleanUrl);
            }
          }
        } catch (e) {
          // Skip invalid URLs
        }
      }
    });

    return [...new Set(links)]; // Remove duplicates
  }

  function initializeVisualization() {
    if (!container) return;

    // Clear previous visualization
    d3.select(container).selectAll("*").remove();

    const width = container.clientWidth;
    const height = container.clientHeight;

    const svgElement = d3
      .select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height);

    svg = svgElement.append("g");

    // Add zoom behavior
    const zoom = d3
      .zoom()
      .scaleExtent([0.1, 4])
      .on("zoom", (event) => {
        svg.attr("transform", event.transform);
      });

    //@ts-ignore
    svgElement.call(zoom);

    // Initialize simulation
    simulation = d3
      .forceSimulation(nodes)
      .force(
        "link",
        d3
          .forceLink(links)
          .id((d: any) => d.id)
          .distance(100)
      )
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(30));
  }

  function updateVisualization() {
    if (!svg) return;

    // Update links
    const linkSelection = svg
      .selectAll(".link")
      .data(links, (d: any) => `${d.source.id}-${d.target.id}`);

    linkSelection
      .enter()
      .append("line")
      .attr("class", "link")
      .attr("stroke", "#999")
      .attr("stroke-opacity", 0.6)
      .attr("stroke-width", 2);

    linkSelection.exit().remove();

    // Update nodes
    const nodeSelection = svg.selectAll(".node").data(nodes, (d: any) => d.id);

    const nodeEnter = nodeSelection
      .enter()
      .append("g")
      .attr("class", "node")
      .call(
        //@ts-ignore
        d3
          .drag()
          .on("start", dragstarted)
          .on("drag", dragged)
          .on("end", dragended)
      );

    nodeEnter
      .append("circle")
      .attr("r", (d: any) => (d.isRoot ? 15 : 8))
      .attr("fill", (d: any) => (d.isRoot ? "#ff6b6b" : "#4ecdc4"))
      .attr("stroke", "#fff")
      .attr("stroke-width", 2);

    nodeEnter
      .append("text")
      .attr("dx", 20)
      .attr("dy", 5)
      .style("font-size", "12px")
      .style("fill", "#ffffff")
      .text((d: any) => {
        try {
          const domain = new URL(d.id).hostname;
          return domain.length > 20 ? domain.substring(0, 17) + "..." : domain;
        } catch {
          return d.id.substring(0, 20) + "...";
        }
      });

    nodeSelection.exit().remove();

    // Restart simulation
    simulation.nodes(nodes);
    simulation.force(
      "link",
      d3
        .forceLink(links)
        .id((d: any) => d.id)
        .distance(100)
    );
    simulation.alpha(0.3).restart();

    // Update positions on tick
    simulation.on("tick", () => {
      svg
        .selectAll(".link")
        .attr("x1", (d: any) => d.source.x)
        .attr("y1", (d: any) => d.source.y)
        .attr("x2", (d: any) => d.target.x)
        .attr("y2", (d: any) => d.target.y);

      svg
        .selectAll(".node")
        .attr("transform", (d: any) => `translate(${d.x},${d.y})`);
    });
  }

  function dragstarted(event: any, d: any) {
    if (!event.active) simulation.alphaTarget(0.3).restart();
    d.fx = d.x;
    d.fy = d.y;
  }

  function dragged(event: any, d: any) {
    d.fx = event.x;
    d.fy = event.y;
  }

  function dragended(event: any, d: any) {
    if (!event.active) simulation.alphaTarget(0);
    d.fx = null;
    d.fy = null;
  }

  async function processUrl(url: string, sourceUrl?: string) {
    if (visitedUrls.has(url) || !isRunning) return;

    visitedUrls.add(url);
    processedCount++;

    // Add node if it doesn't exist
    if (!nodes.find((n) => n.id === url)) {
      nodes.push({
        id: url,
        isRoot: !sourceUrl,
      });
    }

    // Add link if there's a source
    if (
      sourceUrl &&
      !links.find((l) => l.source === sourceUrl && l.target === url)
    ) {
      links.push({
        source: sourceUrl,
        target: url,
      });
    }

    // Update visualization
    updateVisualization();

    // Fetch HTML and extract links
    const html = await fetchHTML(url);
    if (html && isRunning) {
      const extractedLinks = extractLinks(html, url);

      // Add new URLs to pending list
      extractedLinks.slice(0, 5).forEach((link) => {
        // Limit to 5 links per page
        if (!visitedUrls.has(link) && !pendingUrls.includes(link)) {
          pendingUrls.push(link);
        }
      });
    }
  }

  async function startVisualization() {
    if (!(input.startsWith("https://") || input.startsWith("http://"))) {
      input = "https://" + input;
    }
    if (isRunning) {
      // Stop current process
      isRunning = false;
      return;
    }

    // Reset everything
    visitedUrls.clear();
    pendingUrls = [];
    nodes = [];
    links = [];
    currentDepth = 0;
    processedCount = 0;

    if (!input.trim()) return;

    isRunning = true;
    initializeVisualization();

    // Start with root URL
    pendingUrls = [input];

    // Process URLs in batches with depth control
    while (pendingUrls.length > 0 && isRunning && currentDepth < maxDepth) {
      const currentBatch = pendingUrls.splice(0, 3); // Process 3 URLs at a time
      const promises = currentBatch.map((url) => {
        const sourceUrl =
          currentDepth === 0
            ? undefined
            : nodes[Math.floor(Math.random() * nodes.length)]?.id;
        return processUrl(url, sourceUrl);
      });

      await Promise.all(promises);

      // Small delay to make the visualization more visible
      await new Promise((resolve) => setTimeout(resolve, 500));

      if (currentBatch.length > 0) {
        currentDepth++;
      }
    }

    isRunning = false;
  }

  onMount(() => {
    // Auto-start if URL is provided
    if (input) {
      startVisualization();
    }
  });
</script>

<div class="w-full h-[100dvh] p-3">
  <div class="w-full h-full card bg-neutral text-neutral-content flex flex-col">
    <div class="w-full p-2 flex justify-center gap-2 items-center">
      <input
        class="input flex-1 max-w-md"
        bind:value={input}
        placeholder="Enter URL to visualize..."
        disabled={isRunning}
      />

      <button
        class="btn btn-primary"
        class:btn-error={isRunning}
        onclick={startVisualization}
      >
        {isRunning ? "Stop" : "Go"}
      </button>
    </div>

    <div class="w-full h-full relative overflow-hidden" bind:this={container}>
      {#if nodes.length === 0 && !isRunning}
        <div
          class="absolute inset-0 flex items-center justify-center text-base-content/50"
        >
          <div class="text-center">
            <div class="text-6xl mb-4">🔗</div>
            <div>Enter a URL and click Go to start visualizing links</div>
          </div>
        </div>
      {/if}
    </div>
    <div class="divider p-0 m-0 h-[1px]"></div>

    {#if isRunning || processedCount > 0}
      <div class="px-2 py-1 text-xs flex gap-4">
        <span>Processed: {processedCount}</span>
        <span>Pending: {pendingUrls.length}</span>
        <span>Depth: {currentDepth}/{maxDepth}</span>
        <span class:text-success={!isRunning} class:text-warning={isRunning}>
          {isRunning ? "Running..." : "Stopped"}
        </span>
      </div>
    {/if}
  </div>
</div>
