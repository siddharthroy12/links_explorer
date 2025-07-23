export function isValidURL(url: string) {
  if (!(url.startsWith("http://") || url.startsWith("https://"))) {
    url = "https://" + url;
  }
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}

export function fixUrl(url: string) {
  if (!(url.startsWith("http://") || url.startsWith("https://"))) {
    url = "https://" + url;
  }
  return url;
}
