package ht.henrique.mazebank.model.create;

import ht.henrique.mazebank.model.Response;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class CreateResponse implements Response {

    private String message;

}
