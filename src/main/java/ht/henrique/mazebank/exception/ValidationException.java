package ht.henrique.mazebank.exception;

import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.type.ReturnCode;

public class ValidationException extends BaseException {
    public ValidationException(ReturnCode errorCode, String message) {
        super(errorCode, message);
    }
}
