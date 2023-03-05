package ht.henrique.mazebank.model.fetch;

import ht.henrique.mazebank.model.Response;
import jakarta.persistence.Column;
import lombok.Data;

@Data
public class FetchUserResponse implements Response {
    private Integer uid;
    private String userName;
    private Integer userBalance;
    private String userEmail;
}
