import {type JSONSchemaType} from "ajv";
import {type ReactNode} from "react";
import {isString} from "next/dist/build/webpack/plugins/jsconfig-paths-plugin";

export enum Breakpoint {

    xs = "xs",
    sm = "sm",
    md = "md",
    lg = "lg",
    xl = "xl",
    xxl = "xxl",

}

export type BreakpointData<T> = {
    [key in Breakpoint]?: T;
};

export enum ContentType {

    CODE_EDITOR = "CODE_EDITOR",
    VISUAL_EDITOR = "VISUAL_EDITOR",

}

export interface ModalData {

    title?: string | undefined | ReactNode;

    content?: ReactNode | undefined;

    footer?: string | undefined;

    onClose?: () => boolean | undefined;

}

export type MinecraftVersion = "1.18" | "1.19";
export const minecraftVersions: MinecraftVersion[] = ["1.18", "1.19"];

export interface BoundingBox2 {
    min: Vector2;
    max: Vector2;
}

export interface MCItem {
    name: string;
    texture: string | null;
}

/**
 * DATA
 */
export interface ImageData {

    id: string;

    base64: string;

}

export interface CursorData {

    line: number;

    character: number;

}

export type Vector2 = [number, number]; // x, y
export type Vector3 = [number, number, number]; // x, y, z

export interface Vector4 {
    r: number;
    g: number;
    b: number;
    a: number;
}


export interface HoloUIIcon {

    type: 'textImage' | 'animatedTextImage' | 'item' | 'text';

}

export interface HoloUITextImageIcon extends HoloUIIcon {

    type: 'textImage';

    path: string;

}

export interface HoloUIAnimatedTextImageIcon extends HoloUIIcon {
    type: 'animatedTextImage';

    source: string | string[];

    speed: number;
}

export interface HoloUIItemIcon extends HoloUIIcon {

    type: 'item';

    item: string;

    count: number;

    customModelData: number;

}

export interface HoloUITextIcon extends HoloUIIcon {

    type: 'text';

    text: string;

}

export interface HoloUIAction {

    type: 'command' | 'sound';

}

export interface HoloUICommandAction extends HoloUIAction {

    type: 'command';

    command: string;

    source: 'player' | 'server';

}

export interface HoloUISoundAction extends HoloUIAction {

    type: 'sound';

    sound: string;

    source: 'master' | 'music' | 'record' | 'weather' | 'block' | 'hostile' | 'neutral' | 'player' | 'ambient' | 'voice';

    volume: number;

    pitch: number;

}

export interface HoloUIComponentData {

    type: 'button' | 'decoration' | 'toggle'

}

export interface HoloUIButtonData extends HoloUIComponentData {

    type: 'button';

    actions: HoloUIAction[];

    highlightModifier: number;

    icon: HoloUIIcon;

}

export interface HoloUIDecorationData extends HoloUIComponentData {

    type: 'decoration';

    icon: HoloUIIcon;
}

export interface HoloUIToggleData extends HoloUIComponentData {

    type: 'toggle';

    highlightModifier: number;

    condition: string;

    expectedValue: string;

    trueActions: HoloUIAction[];

    falseActions: HoloUIAction[];

    trueIcon: HoloUIIcon;

    falseIcon: HoloUIIcon;

}


export interface HoloUIComponent {

    id: string;

    offset: Vector3;

    data: HoloUIComponentData;


}

export interface HoloUIData {

    offset: Vector3;

    components: HoloUIComponent[];

    lockPosition: boolean;

    followPlayer: boolean;
}

export type HoloUISchema = JSONSchemaType<HoloUIAction>;

/**
 * Convert an icon to a HoloUIIcon
 *
 * @param iconType the type of icon
 * @param icon the icon
 */
export function convertToIcon(iconType: 'text' | 'image' | 'item', icon: string): HoloUIIcon {
    if (iconType === 'text') {
        return {
            type: 'text',
            text: icon,
        } as HoloUITextIcon;
    }

    if (iconType === 'image') {
        return {
            type: 'textImage',
            path: icon,
        } as HoloUITextImageIcon;
    }

    return {
        type: 'item',
        item: icon,
        count: 1,
        customModelData: 0
    } as HoloUIItemIcon;
}