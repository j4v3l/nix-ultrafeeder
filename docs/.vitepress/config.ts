// @ts-nocheck
import { defineConfig } from "vitepress";

export default defineConfig({
  title: "nix-ultrafeeder",
  description: "NixOS modules for Ultrafeeder, feeders, Skystats, and Airband",
  lang: "en-US",
  head: [
    ["link", { rel: "icon", type: "image/svg+xml", href: "/nixos.svg" }],
  ],
  themeConfig: {
    nav: [
      { text: "Home", link: "/" },
      { text: "Getting Started", link: "/guide/getting-started" },
      { text: "Configuration", link: "/guide/configuration" },
      { text: "Secrets & Updates", link: "/guide/secrets-updates" },
      { text: "Modules", link: "/reference/modules" },
      { text: "Examples", link: "/reference/examples" },
      { text: "Testing", link: "/reference/testing" },
    ],
    sidebar: {
      "/": [
        {
          text: "Guide",
          collapsed: false,
          items: [
            { text: "Getting Started", link: "/guide/getting-started" },
            { text: "Configuration", link: "/guide/configuration" },
            { text: "Secrets & Auto-Update", link: "/guide/secrets-updates" },
          ],
        },
        {
          text: "Reference",
          collapsed: false,
          items: [
            { text: "Modules", link: "/reference/modules" },
            { text: "Examples & Recipes", link: "/reference/examples" },
            { text: "Testing", link: "/reference/testing" },
          ],
        },
      ],
      "/guide/": [
        {
          text: "Guide",
          collapsed: false,
          items: [
            { text: "Getting Started", link: "/guide/getting-started" },
            { text: "Configuration", link: "/guide/configuration" },
            { text: "Secrets & Auto-Update", link: "/guide/secrets-updates" },
          ],
        },
        {
          text: "Reference",
          collapsed: false,
          items: [
            { text: "Modules", link: "/reference/modules" },
            { text: "Examples & Recipes", link: "/reference/examples" },
            { text: "Testing", link: "/reference/testing" },
          ],
        },
      ],
      "/reference/": [
        {
          text: "Guide",
          collapsed: false,
          items: [
            { text: "Getting Started", link: "/guide/getting-started" },
            { text: "Configuration", link: "/guide/configuration" },
            { text: "Secrets & Auto-Update", link: "/guide/secrets-updates" },
          ],
        },
        {
          text: "Reference",
          collapsed: false,
          items: [
            { text: "Modules", link: "/reference/modules" },
            { text: "Examples & Recipes", link: "/reference/examples" },
            { text: "Testing", link: "/reference/testing" },
          ],
        },
      ],
    },
    socialLinks: [
      { icon: "github", link: "https://github.com/j4v3l/nix-ultrafeeder" },
    ],
    footer: {
      message: "Licensed under the MIT License",
      copyright: "© 2025 nix-ultrafeeder",
    },
  },
});

