"use client";

import { Monitor, Moon, Sun } from "lucide-react";

import { Button } from "@/components/ui/button";
import { THEME_MODE_OPTIONS } from "@/lib/preferences/theme";
import { persistPreference } from "@/lib/preferences/preferences-storage";
import { usePreferencesStore } from "@/stores/preferences/preferences-provider";

const THEME_CYCLE = ["light", "dark", "system"] as const;

// aria-label 里不能直接插值 themeMode（它是 light/dark/system 这类值），
// 否则读屏会念出英文；这里映射成 THEME_MODE_OPTIONS 里的中文标签。
const THEME_MODE_LABELS: Record<string, string> = Object.fromEntries(
  THEME_MODE_OPTIONS.map((o) => [o.value, o.label]),
);

export function ThemeSwitcher() {
  const themeMode = usePreferencesStore((s) => s.themeMode);
  const setThemeMode = usePreferencesStore((s) => s.setThemeMode);

  const cycleTheme = () => {
    const currentIndex = THEME_CYCLE.indexOf(themeMode);
    const nextTheme = THEME_CYCLE[(currentIndex + 1) % THEME_CYCLE.length];

    setThemeMode(nextTheme);
    void persistPreference("theme_mode", nextTheme);
  };

  return (
    <Button size="icon" onClick={cycleTheme} aria-label={`当前主题：${THEME_MODE_LABELS[themeMode] ?? themeMode}，点击切换主题`}>
      {/* SYSTEM */}
      <Monitor className="hidden [html[data-theme-mode=system]_&]:block" />

      {/* DARK (resolved) */}
      <Sun className="hidden dark:block [html[data-theme-mode=system]_&]:hidden" />

      {/* LIGHT (resolved) */}
      <Moon className="block dark:hidden [html[data-theme-mode=system]_&]:hidden" />
    </Button>
  );
}
