<script lang="ts">
  import type { KeyboardEventHandler } from "svelte/elements";
  import Visualization from "../components/visualization.svelte";
  import { fixUrl, isValidURL } from "../utils";
  let inputURL = $state("");
  let showVisualization = $state(false);

  let fullUrl = $derived(fixUrl(inputURL));

  let isValidInput = $derived(isValidURL(fullUrl));

  function startScaping() {
    showVisualization = true;
  }

  const handleEnterPress: KeyboardEventHandler<HTMLInputElement> = (event) => {
    if (event.key === "Enter" && isValidInput) {
      startScaping();
    }
  };
</script>

{#if showVisualization}
  <Visualization url={fullUrl} />
{:else}
  <div class="flex justify-center flex-col w-full h-[100dvh] items-center">
    <div
      class="max-w-[500px] flex justify-center flex-col items-center gap-12 px-3"
    >
      <h1 class="text-2xl sm:text-4xl text-center">
        <span class="font-extrabold">Visualize links</span> between
        <span class="font-extrabold">pages </span> in
        <span class="font-extrabold">single click!</span>
      </h1>

      <div
        class="flex justify-center items-center gap-2 w-full flex-col sm:flex-row"
      >
        <input
          class="input sm:max-w-[300px] w-full"
          placeholder="Enter page URL"
          bind:value={inputURL}
          onkeydown={handleEnterPress}
        />
        <button
          aria-label="Start Scraping"
          class="btn btn-soft w-full sm:w-fit"
          onclick={startScaping}
          disabled={!isValidInput}>Start 🚀</button
        >
      </div>
    </div>
  </div>
{/if}
