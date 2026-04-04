package ht.henrique.mazebank.exception;

import ht.henrique.mazebank.model.type.ReturnCode;
import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class ControllerException extends BaseException {
    public ControllerException(ReturnCode errorCode, String message){
        super(errorCode, message);
    }
}
