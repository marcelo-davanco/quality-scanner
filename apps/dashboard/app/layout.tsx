import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Quality Scanner Dashboard",
  description: "Dashboard de resultados do Quality Scanner",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
