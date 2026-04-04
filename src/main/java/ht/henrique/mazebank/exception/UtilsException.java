package ht.henrique.mazebank.exception;

import ht.henrique.mazebank.model.type.ReturnCode;

public class UtilsException extends BaseException{
    public UtilsException(ReturnCode errorCode, String message) {
        super(errorCode, message);
    }
}
