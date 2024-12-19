import Footer from "@/components/Footer";
import Header from "@/components/Header";
import SideBar from "@/components/SideBar";
import PageContent from "@/components/PageContent";

export default function Page() {
    return (
        <>
            <Header/>
            <main>
                <SideBar/>
                <PageContent/>
            </main>
            <Footer/>
        </>
    )
}

// hi
