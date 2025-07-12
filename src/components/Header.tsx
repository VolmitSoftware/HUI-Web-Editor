import styles from "@/styles/components/Header.module.scss";

export default function Header() {
    return (
        <header className={styles.header}>
            <a className={styles.brand} href="https://holoui.volmit.com/" target={"_blank"}>
                <div className={styles.brandName}>
                    <h1>
                        <span>Volmit Software</span> - HoloUi Editor.
                    </h1>
                </div>
            </a>
        </header>
    );
}