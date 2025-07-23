/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//@ts-nocheck
import React, { useEffect } from 'react';
import * as Flex from '@twilio/flex-ui'; // eslint-disable-line node/no-unpublished-import

import { useScript } from '../../../../../third_party/twilioflex/hooks/useScript';
import {
    ChatMessage,
    ChatBubble,
    ChatMessageMeta,
    ChatMessageMetaItem,
    useChatLogger,
    ChatLogger,
} from '@twilio-paste/chat-log';
import { Box } from '@twilio-paste/core/box';

type messageVariant = 'inbound' | 'outbound';

const transcriptFactory = (
    variant: messageVariant,
    message: string,
    metaLabel: string
) => {
    const time = new Date().toLocaleString('en-US', {
        hour: 'numeric',
        minute: 'numeric',
        hour12: true,
    });
    return {
        variant,
        content: (
            <ChatMessage variant={variant}>
                <ChatBubble>{message}</ChatBubble>
                <ChatMessageMeta aria-label={metaLabel + time}>
                    <ChatMessageMetaItem>{time}</ChatMessageMetaItem>
                </ChatMessageMeta>
            </ChatMessage>
        ),
    };
};

export const Transcript = (): JSX.Element | null => {
    const { chats, push } = useChatLogger();
    useEffect(() => {
        const newMessageReceivedHandler = (event: MessageEvent) => {
            // Ensure the event has the expected structure
            if (!event.data || !event.data.type || !event.data.detail) {
                return;
            }

            switch (event.data.type) {
                case 'new-message-received':
                    const { participantRole, content } = event.data.detail;
                    const variant = participantRole === 'END_USER' ? 'inbound' : 'outbound';
                    const metaLabel =
                        participantRole === 'END_USER' ? 'said by customer at ' : 'said by agent at ';
                    push(transcriptFactory(variant, content, metaLabel));
                    break;
            }
        };

        window.addEventListener('message', newMessageReceivedHandler);

        return () => {
            window.removeEventListener('message', newMessageReceivedHandler);
        };
    },[]);

    return (
        <Box
            display="flex"
            flex="1 1 auto"
            overflow="auto"
            paddingX="space70"
            paddingY="space80"
            lineHeight="lineHeight20"
            color="colorText"
        >
            <Box width="100%"><ChatLogger chats={chats} /></Box>
        </Box>
    );
};

Transcript.displayName = 'Transcript';
