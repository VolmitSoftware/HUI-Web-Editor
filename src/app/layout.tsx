import {type ReactNode} from "react";
import {type Metadata, Viewport} from "next";
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
    metadataBase: new URL(process.env.NODE_ENV === "production" ? "https://holoui.studioarchetype.net" : "http://localhost:3000"),
    openGraph: {
        type: 'website',
        locale: 'en_US',
        siteName: 'HoloUI Builder',
        title: 'HoloUI Builder',
        description: 'Web builder for creating and previewing HUI configs.',
        url: 'https://holoui.studioarchetype.net/',
        images: [
            "/logo.webp"
        ],
    },
    twitter: {
        creator: '@studioarchetype',
        card: 'summary_large_image',
        title: 'HoloUI Builder',
        description: 'Web builder for creating and previewing HUI configs.',
        site: '@studioarchetype',
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
        "studio archetype",
        "studioarchetype"
    ],
    category: "Web Application",
    robots: {
        follow: true,
        index: true,
    },
    creator: "Studio Archetype",
    authors: {
        name: "Studio Archetype",
        url: "https://studioarchetype.net/",
    },
    publisher: "Studio Archetype",

}

export const viewport: Viewport = {
    width: "device-width",
    initialScale: 1,
    colorScheme: "dark",
}

export default function RootLayout({
                                       children,
                                   }: {
    children: ReactNode
}) {
    return (
        <html lang="en">
        <body>
        <ContextProviders>
            {children}
        </ContextProviders>
        </body>
        </html>
    )
}
