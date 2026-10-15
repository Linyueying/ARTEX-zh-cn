"use client";

import Link from "next/link";

import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <div className="flex h-dvh flex-col items-center justify-center space-y-2 text-center">
      <h1 className="font-semibold text-2xl">页面未找到。</h1>
      <p className="text-muted-foreground">找不到你要访问的页面。</p>
      <Link prefetch={false} replace href="/function/tasks">
        <Button variant="outline">返回首页</Button>
      </Link>
    </div>
  );
}
