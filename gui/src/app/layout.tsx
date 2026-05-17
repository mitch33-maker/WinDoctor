import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "WindowsDoctor | AI 診斷專家",
  description: "專業 Windows 10/11 問題研判與修復系統 (PWA)",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-TW" className="dark">
      <body className={`${inter.className} bg-[#050505] text-white antialiased`}>
        {children}
      </body>
    </html>
  );
}
