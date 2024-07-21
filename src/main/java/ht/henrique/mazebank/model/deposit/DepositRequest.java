package ht.henrique.mazebank.model.deposit;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class DepositRequest {

    @JsonProperty("value")
    private Float value;
}
