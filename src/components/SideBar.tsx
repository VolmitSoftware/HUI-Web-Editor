"use client";

import {FaImage, FaQuestion, FaSave, FaUpload} from "react-icons/fa";
import {BsBoxes, BsCodeSlash, BsGear} from "react-icons/bs";
import styles from "@/styles/components/SideBar.module.scss";
import {useContent} from "@/hooks/ContentHook";
import {ContentType, type HoloUIData, type ModalData} from "@/util/types";
import {joinedClassNames} from "@/util/classes";
import {useModal} from "@/hooks/ModalHook";
import ImageManagerModal from "@/components/modal/ImageManagerModal";
import AboutModal from "@/components/modal/AboutModal";
import {createRef, useEffect} from "react";
import SettingsModal from "@/components/modal/SettingsModal";
import {useComponent} from "@/hooks/ComponentHook";

const imageManagerModal: ModalData = {
    title: "Image Management",
    content: <ImageManagerModal/>
};

const aboutModal: ModalData = {
    title: "About Application",
    content: <AboutModal/>,
    footer: "Version: 2.0.0",
}

const settingsModal: ModalData = {
    title: "Settings",
    content: <SettingsModal/>,
}

export default function SideBar() {
    const {contentType, switchContentType} = useContent();
    const {data, setData, validateData} = useComponent();
    const {setModal} = useModal();
    const importInputRef = createRef<HTMLInputElement>();
    const exportAnchorRef = createRef<HTMLAnchorElement>();

    /**
     * Handles the toggle content nav item click event.
     */
    function handleToggleContent() {
        switchContentType();
    }

    /**
     * Handles the import click event.
     */
    function handleImportClick() {
        const current = importInputRef.current;
        if (!current) {
            return;
        }

        current.click();
    }

    /**
     * Handles the export click event.
     */
    function handleExportClick() {
        const current = exportAnchorRef.current;
        if (!current) {
            return;
        }

        if (!data) {
            alert("There is no data to export.");
            return;

        }

        data.components.map(component => component.offset[1] * -1)

        const dataStr = JSON.stringify(data, null, 4);

        console.log(dataStr)

        // Set the anchor href
        current.href = "data:application/json;charset=utf-8," + encodeURIComponent(dataStr);
        // Click the anchor
        current.click();
    }

    // Add event listener to import input
    useEffect(() => {
        const current = importInputRef.current;
        if (!current) {
            return;
        }

        function handleInputChange() {
            if (!current) {
                return;
            }

            const uploadedFile = current.files?.[0];
            // Check if a file was uploaded
            if (!uploadedFile) {
                current.value = "";
                return;
            }

            const reader = new FileReader();

            // Read the file
            reader.readAsText(uploadedFile);

            // Handle the file
            reader.onload = () => {
                // Clear the input (so the user can upload the same image again)
                if (current) {
                    current.value = "";
                }

                const result = reader.result;
                if (!result) {
                    return;
                }

                // Parse the result
                const error = validateData(result as string);
                if (error) {
                    alert(`${uploadedFile.name} is not a valid HoloUI file. Please check the console for more information.`);
                    console.error(error);
                    return;
                }

                // Set the data
                const data = JSON.parse(result as string) as HoloUIData;

                // Set the data
                setData(data);
                alert(`${uploadedFile.name} was successfully imported.`);
            };

        }

        // Add event listener
        current.addEventListener("change", handleInputChange);

        return () => {
            current.removeEventListener("change", handleInputChange);
        }
    }, [importInputRef]);

    return (
        <div className={styles.sideBar}>
            <div className={styles.navItems}>
                <div
                    className={joinedClassNames([styles.navItem, styles.hasDivider])}
                    onClick={handleToggleContent}
                    data-label={contentType === ContentType.CODE_EDITOR ? "Visual Editor" : "Code Editor"}
                >
                    {
                        contentType === ContentType.CODE_EDITOR ? (
                            <BsBoxes/>
                        ) : (
                            <BsCodeSlash/>
                        )
                    }
                </div>
                <div className={styles.divider}>
                    <hr/>
                </div>
                <div
                    className={styles.navItem}
                    data-label="Import"
                    onClick={handleImportClick}
                >
                    <FaUpload/>
                    <input
                        className={styles.hidden}
                        type="file"
                        accept={"application/json"}
                        ref={importInputRef}
                    />
                </div>
                <div
                    className={styles.navItem}
                    data-label="Export"
                    onClick={handleExportClick}
                >
                    <FaSave/>
                    <a
                        className={styles.hidden}
                        target={"_blank"}
                        href={""}
                        download={"holoui.json"}
                        ref={exportAnchorRef}
                    />
                </div>
                <div
                    className={styles.navItem}
                    data-label="Image Managment"
                    onClick={() => setModal(imageManagerModal)}
                >
                    <FaImage/>
                </div>
            </div>
            <div className={styles.navItems}>
                <div
                    className={styles.navItem}
                    data-label="Settings"
                    onClick={() => setModal(settingsModal)}
                >
                    <BsGear/>
                </div>
                <div
                    className={styles.navItem}
                    data-label="About"
                    onClick={() => setModal(aboutModal)}
                >
                    <FaQuestion/>
                </div>
            </div>
        </div>
    )
}