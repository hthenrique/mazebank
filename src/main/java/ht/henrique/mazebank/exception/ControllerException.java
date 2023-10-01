package ht.henrique.mazebank.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class ControllerException extends BaseException {
    public ControllerException(HttpStatus httpStatus, Integer errorCode, String message){
        super(httpStatus, errorCode, message);
    }
}
