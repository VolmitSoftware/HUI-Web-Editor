import Row from "@/components/grid/Row";
import Column from "@/components/grid/Column";
import styles from "@/styles/components/visual/VisualButtons.module.scss";
import {type ModalData} from "@/util/types";
import {useModal} from "@/hooks/ModalHook";
import {BsQuestionLg} from "react-icons/bs";
import StaticComponentModal from "@/components/modal/edit/type/static/StaticComponentModal";
import ButtonComponentModal from "@/components/modal/edit/type/button/ButtonComponentModal";
import ToggleComponentModal from "@/components/modal/edit/type/toggle/ToggleComponentModal";

const addStaticModal: ModalData = {
    title: "Add Static Component",
    content: <StaticComponentModal isCreate={true}/>,
};
const addButtonModal: ModalData = {
    title: "Add Button Component",
    content: <ButtonComponentModal isCreate={true}/>,
};
const addToggleModal: ModalData = {
    title: (
        <div className={styles.modalHeaderTitle}>
            <h3>
                Add Toggle Component
            </h3>
            <a
                href={"https://docs.volmit.com/hologui"}
                target={"_blank"}
                referrerPolicy={"no-referrer"}
                data-label={"Toggle Documentation"}
            >
                <BsQuestionLg/>
            </a>
        </div>
    ),
    content: <ToggleComponentModal isCreate={true}/>,
}

export default function VisualButtons() {
    const {setModal} = useModal();

    return (
        <div className={styles.visualButtons}>
            <Row>
                <Column xs={24}>
                    <div className={styles.header}>
                        <h2>
                            Add a Component
                        </h2>
                    </div>
                </Column>
                <Column
                    xs={24}
                    lg={8}
                >
                    <div
                        className={styles.button}
                        onClick={() => setModal(addStaticModal)}
                    >
                        <h3>
                            Static
                        </h3>
                    </div>
                </Column>
                <Column
                    xs={24}
                    lg={8}
                >
                    <div
                        className={styles.button}
                        onClick={() => setModal(addButtonModal)}
                    >
                        <h3>
                            Button
                        </h3>
                    </div>
                </Column>
                <Column
                    xs={24}
                    lg={8}
                >
                    <div
                        className={styles.button}
                        onClick={() => setModal(addToggleModal)}
                    >
                        <h3>
                            Toggle
                        </h3>
                    </div>
                </Column>
            </Row>
        </div>
    )
}