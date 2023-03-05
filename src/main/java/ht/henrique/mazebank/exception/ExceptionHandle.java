package ht.henrique.mazebank.exception;

import ht.henrique.mazebank.model.error.ErrorTemplate;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import java.sql.Timestamp;
import java.util.Date;

@ControllerAdvice
@Slf4j
public class ExceptionHandle {

    @ExceptionHandler(value = {ControllerException.class})
    public ResponseEntity<ErrorTemplate> ControllerException(ControllerException exception){

        ErrorTemplate errorTemplate = new ErrorTemplate();
        errorTemplate.setErrorCode(exception.getErrorCode());
        errorTemplate.setErrorMessage(exception.getMessage());

        return handleException(errorTemplate,exception.getHttpStatus());
    }

    @ExceptionHandler(value = {DatabaseException.class})
    public ResponseEntity<ErrorTemplate> DatabaseException(DatabaseException exception){

        ErrorTemplate errorTemplate = new ErrorTemplate();
        errorTemplate.setErrorCode(exception.getErrorCode());
        errorTemplate.setErrorMessage(exception.getMessage());

        return handleException(errorTemplate,exception.getHttpStatus());
    }


    public ResponseEntity<ErrorTemplate> handleException(ErrorTemplate errorTemplate, HttpStatus httpStatus) {
        Date date = new Date();
        errorTemplate.setTimeStamp(new Timestamp(date.getTime()).toString());
        log.info(errorTemplate.toString());
        return ResponseEntity.status(httpStatus).body(errorTemplate);
    }
}
