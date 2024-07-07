package ht.henrique.mazebank.exception;

import ht.henrique.mazebank.model.type.ReturnCode;
import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class DatabaseException extends BaseException{

    public DatabaseException(ReturnCode errorCode, String message){
        super(errorCode, message);
    }
}
