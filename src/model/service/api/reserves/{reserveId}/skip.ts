import { Operation } from 'express-openapi';
import IReserveApiModel from '../../../../api/reserve/IReserveApiModel';
import container from '../../../../ModelContainer';
import * as api from '../../../api';

export const del: Operation = async (req, res) => {
    const reserveApiModel = container.get<IReserveApiModel>('IReserveApiModel');

    try {
        api.responseJSON(res, 200, await reserveApiModel.removeSkip(parseInt(req.params.reserveId, 10)));
    } catch (err: any) {
        api.responseServerError(res, err.message);
    }
};

del.apiDoc = {
    summary: '予約の除外状態を解除',
    tags: ['reserves'],
    description: '予約の除外状態を解除する',
    parameters: [
        {
            $ref: '#/components/parameters/PathReserveId',
        },
    ],
    responses: {
        200: {
            description: '予約の除外状態を解除しました',
        },
        default: {
            description: '予期しないエラー',
            content: {
                'application/json': {
                    schema: {
                        $ref: '#/components/schemas/Error',
                    },
                },
            },
        },
    },
};
