import {type ReactNode} from "react";
import {type Metadata, type Viewport} from "next";
import { JetBrains_Mono } from 'next/font/google'
import "@/styles/global.scss";
import ContextProviders from "@/components/ContextProviders";

export const metadata: Metadata = {
    title: 'HoloUI Builder',
    description: 'Web builder for creating and previewing HUI configs.',
    icons: [
        "/favicon-16x16.png",
        "/favicon-32x32.png",
        "/favicon.ico",
    ],
    metadataBase: new URL(process.env.NODE_ENV === "production" ? "https://holoui.volmit.com" : "http://localhost:3000"),
    openGraph: {
        type: 'website',
        locale: 'en_US',
        siteName: 'HoloUI Builder',
        title: 'HoloUI Builder',
        description: 'Web builder for creating and previewing HUI configs.',
        url: 'https://holoui.volmit.com/',
        images: [
            "/logo.webp"
        ],
    },
    twitter: {
        creator: '@VolmitSoftware',
        card: 'summary_large_image',
        title: 'HoloUI Builder',
        description: 'Web builder for creating and previewing HUI configs.',
        site: '@VolmitSoftware',
        images: [
            "/logo.webp"
        ],
    },
    keywords: [
        "holo",
        "hui",
        "holoui",
        "holo ui",
        "holo ui builder",
        "holoui builder",
        "holo ui config",
        "holoui config",
        "holo ui config builder",
        "volmit software",
        "volmitsoftware"
    ],
    category: "Web Application",
    robots: {
        follow: true,
        index: true,
    },
    creator: "VolmitSoftware",
    authors: {
        name: "VolmitSoftware",
        url: "https://volmit.com/",
    },
    publisher: "Volmit Software",

}

export const viewport: Viewport = {
    width: "device-width",
    initialScale: 1,
    colorScheme: "dark",
}

const JetBrainsFont = JetBrains_Mono({ subsets: ["latin"] })

export default function RootLayout({
                                       children,
                                   }: {
    children: ReactNode
}) {
    return (
        <html lang="en">
        <body className={JetBrainsFont.className}>
        <ContextProviders>
            {children}
        </ContextProviders>
        </body>
        </html>
    )
}
