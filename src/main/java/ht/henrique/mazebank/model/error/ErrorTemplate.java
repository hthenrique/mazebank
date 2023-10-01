package ht.henrique.mazebank.model.error;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ErrorTemplate {

    private Integer errorCode;
    private String errorMessage;
    private String timeStamp;
}
