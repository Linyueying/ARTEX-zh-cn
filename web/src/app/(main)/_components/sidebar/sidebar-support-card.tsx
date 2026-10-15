import Link from "next/link";

import { siX } from "simple-icons";

import { SimpleIcon } from "@/components/simple-icon";
import { Card, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export function SidebarSupportCard() {
  return (
    <Card size="sm" className="overflow-hidden shadow-none group-data-[collapsible=icon]:hidden">
      <CardHeader className="min-w-0 px-4">
        <CardTitle className="truncate text-sm">想找更多内容？</CardTitle>
        <CardDescription className="line-clamp-2">
          提交 issue 或通过以下方式联系我&nbsp;
          <Link
            href="https://x.com/arhamkhnz"
            target="_blank"
            rel="noreferrer"
            aria-label="在 X 上联系我"
            className="inline-flex items-center text-foreground"
          >
            <SimpleIcon icon={siX} aria-hidden className="size-3 fill-current" />
          </Link>
          .
        </CardDescription>
      </CardHeader>
    </Card>
  );
}
