library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;

entity project_reti_logiche is
  port (
    i_clk      : in  std_logic;
    i_rst      : in  std_logic;
    i_start    : in  std_logic;
    i_add      : in  std_logic_vector(15 downto 0);
    o_done     : out std_logic;
    o_mem_addr : out std_logic_vector(15 downto 0);
    i_mem_data : in  std_logic_vector(7 downto 0);
    o_mem_data : out std_logic_vector(7 downto 0);
    o_mem_we   : out std_logic;
    o_mem_en   : out std_logic
  );
end entity;

architecture Behavioral of project_reti_logiche is
  type state is (RESET, START, ASK_MEM, WAIT_MEM, READ_K1, READ_K2, READ_T, READ_FILTER, SHIFT_FILTER, READ_WORD, SHIFT_WORD, CALC_RESULT, NORMALIZE_RESULT, WRITE_RESULT, TERMINATE);

  signal prev_state    : state;
  signal current_state : state;
  signal next_state    : state;

  signal K                   : std_logic_vector(15 downto 0);
  signal writing_address_reg : std_logic_vector(15 downto 0);
  signal reading_address_reg : std_logic_vector(15 downto 0);
  signal typeof_filter_reg   : std_logic := '0';
  signal filters_reg         : std_logic_vector(55 downto 0);
  signal memorized_words_reg : std_logic_vector(55 downto 0);
  signal result_buffer_reg   : std_logic_vector(23 downto 0);
  signal reads_counter       : std_logic_vector(23 downto 0);

  signal resetting          : std_logic;
  signal starting           : std_logic;
  signal asking             : std_logic;
  signal reading_k1         : std_logic;
  signal reading_k2         : std_logic;
  signal reading_t          : std_logic;
  signal reading_filter     : std_logic;
  signal shifting_filters   : std_logic;
  signal reading_w          : std_logic;
  signal shifting_w         : std_logic;
  signal calculating_result : std_logic;
  signal normalizing_result : std_logic;
  signal writing_result     : std_logic;
  signal terminating        : std_logic;

begin
  combinatory_logic: process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if (starting = '1') then
        o_done <= '0';
        o_mem_addr <= i_add;

      elsif (asking = '1') then
        o_mem_addr <= reading_address_reg;

      elsif (reading_k1 = '1') then
        K(15 downto 8) <= i_mem_data;
        reading_address_reg <= std_logic_vector(unsigned(reading_address_reg) + 1);

      elsif (reading_k2 = '1') then
        K(7 downto 0) <= i_mem_data;
        reading_address_reg <= std_logic_vector(unsigned(reading_address_reg) + 1);

      elsif (reading_t = '1') then
        if (i_mem_data(0) = '1') then
          typeof_filter_reg <= '1';
          reading_address_reg <= std_logic_vector(unsigned(reading_address_reg) + 8);
        else
          typeof_filter_reg <= '0';
          reading_address_reg <= std_logic_vector(unsigned(reading_address_reg) + 1);
        end if;
        writing_address_reg <= std_logic_vector(unsigned(i_add) + unsigned(K) + 17);

      elsif (reading_filter = '1') then
        filters_reg(7 downto 0) <= i_mem_data;
        if (typeof_filter_reg = '1') then
          reading_address_reg <= std_logic_vector(unsigned(reading_address_reg) + 1);
        else
          if (unsigned(reading_address_reg) > (unsigned(i_add) + 8)) then
            reading_address_reg <= std_logic_vector(unsigned(reading_address_reg) + 8);
          else
            reading_address_reg <= std_logic_vector(unsigned(reading_address_reg) + 1);
          end if;
        end if;

      elsif (shifting_filters = '1') then
        filters_reg <= std_logic_vector(unsigned(filters_reg) sll 8);

      elsif (reading_w = '1') then
        memorized_words_reg(7 downto 0) <= i_mem_data;
        reading_address_reg <= std_logic_vector(unsigned(reading_address_reg) + 1);
        reads_counter <= std_logic_vector(unsigned(reads_counter) + 1);

      elsif (shifting_w = '1') then
        memorized_words_reg <= std_logic_vector(unsigned(memorized_words_reg) sll 8);

      elsif (calculating_result = '1') then
        if (typeof_filter_reg = '0') then
          result_buffer_reg <= std_logic_vector(
            resize(signed(memorized_words_reg(15 downto 8)) * signed(filters_reg(15 downto 8)), 24) + resize(signed(memorized_words_reg(23 downto 16)) * signed(filters_reg(23 downto 16)), 24) + resize(signed(memorized_words_reg(31 downto 24)) * signed(filters_reg(31 downto 24)), 24) + resize(signed(memorized_words_reg(39 downto 32)) * signed(filters_reg(39 downto 32)), 24) + resize(signed(memorized_words_reg(47 downto 40)) * signed(filters_reg(47 downto 40)), 24)
          );
        else
          result_buffer_reg <= std_logic_vector(
            resize(signed(memorized_words_reg(7 downto 0)) * signed(filters_reg(7 downto 0)), 24) + resize(signed(memorized_words_reg(15 downto 8)) * signed(filters_reg(15 downto 8)), 24) + resize(signed(memorized_words_reg(23 downto 16)) * signed(filters_reg(23 downto 16)), 24) + resize(signed(memorized_words_reg(31 downto 24)) * signed(filters_reg(31 downto 24)), 24) + resize(signed(memorized_words_reg(39 downto 32)) * signed(filters_reg(39 downto 32)), 24) + resize(signed(memorized_words_reg(47 downto 40)) * signed(filters_reg(47 downto 40)), 24) + resize(signed(memorized_words_reg(55 downto 48)) * signed(filters_reg(55 downto 48)), 24)
          );
        end if;

      elsif (normalizing_result = '1') then
        if (typeof_filter_reg = '0') then
          if (signed(result_buffer_reg) >= 0) then
            result_buffer_reg <= std_logic_vector(
              shift_right(signed(result_buffer_reg), 4) + shift_right(signed(result_buffer_reg), 6) + shift_right(signed(result_buffer_reg), 8) + shift_right(signed(result_buffer_reg), 10)
            );
          else
            result_buffer_reg <= std_logic_vector(
              shift_right(signed(result_buffer_reg), 4) + shift_right(signed(result_buffer_reg), 6) + shift_right(signed(result_buffer_reg), 8) + shift_right(signed(result_buffer_reg), 10) + 4
            );
          end if;
        else
          if (signed(result_buffer_reg) >= 0) then
            result_buffer_reg <= std_logic_vector(
              shift_right(signed(result_buffer_reg), 6) + shift_right(signed(result_buffer_reg), 10)
            );
          else
            result_buffer_reg <= std_logic_vector(
              shift_right(signed(result_buffer_reg), 6) + shift_right(signed(result_buffer_reg), 10) + 2
            );
          end if;
        end if;
        o_mem_addr <= writing_address_reg;

      elsif (writing_result = '1') then
        if (signed(result_buffer_reg) > to_signed(127, 24)) then
          o_mem_data <= std_logic_vector(to_signed(127, 8));
        elsif (signed(result_buffer_reg) < to_signed(- 128, 24)) then
          o_mem_data <= std_logic_vector(to_signed(- 128, 8));
        else
          o_mem_data <= std_logic_vector(resize(signed(result_buffer_reg), 8));
        end if;
        writing_address_reg <= std_logic_vector(unsigned(writing_address_reg) + 1);

      elsif (terminating = '1') then
        o_done <= '1';

      elsif (resetting = '1') then
        o_done <= '0';
        o_mem_addr <= i_add;
        o_mem_data <= (others => '0');
        reading_address_reg <= i_add;
        writing_address_reg <= (others => '0');
        typeof_filter_reg <= '0';
        filters_reg <= (others => '0');
        memorized_words_reg <= (others => '0');
        result_buffer_reg <= (others => '0');
        reads_counter <= (others => '0');
        K <= (others => '0');
      else
      end if;
    end if;
  end process;

  fsm_update_state: process (i_clk, i_rst)
  begin
    if (i_rst = '1') then
      prev_state <= RESET;
      current_state <= RESET;
    elsif rising_edge(i_clk) then
      if (next_state = ASK_MEM) then
        prev_state <= current_state;
      end if;
      current_state <= next_state;
    end if;
  end process;

  fsm_state_logic: process (current_state, i_start)
  begin
    case current_state is

      when RESET =>
        if (i_start = '1') then
          next_state <= START;
        else
          next_state <= RESET;
        end if;
      when START =>
        next_state <= ASK_MEM;

      when READ_K1 =>
        next_state <= ASK_MEM;

      when READ_K2 =>
        next_state <= ASK_MEM;

      when READ_T =>
        next_state <= ASK_MEM;

      when READ_FILTER =>
        next_state <= ASK_MEM;

      when SHIFT_FILTER =>
        next_state <= READ_FILTER;

      when READ_WORD =>
        if (unsigned(reads_counter) < 3) then
          next_state <= ASK_MEM;
        else
          next_state <= CALC_RESULT;
        end if;

      when SHIFT_WORD =>
        if (unsigned(reads_counter) >= unsigned(K)) then
          next_state <= CALC_RESULT;
        else
          next_state <= READ_WORD;
        end if;

      when CALC_RESULT =>
        next_state <= NORMALIZE_RESULT;

      when NORMALIZE_RESULT =>
        next_state <= WRITE_RESULT;

      when WRITE_RESULT =>
        next_state <= ASK_MEM;

      when TERMINATE =>
        if (i_start = '0') then
          next_state <= RESET;
        else
          next_state <= TERMINATE;
        end if;

      when ASK_MEM =>
        next_state <= WAIT_MEM;

      when WAIT_MEM =>
        case prev_state is
          when START =>
            next_state <= READ_K1;
          when READ_K1 =>
            next_state <= READ_K2;
          when READ_K2 =>
            next_state <= READ_T;
          when READ_T =>
            next_state <= READ_FILTER;
          when READ_FILTER =>
            if (typeof_filter_reg = '1') then
              if (unsigned(reading_address_reg) > (unsigned(i_add) + 16)) then
                next_state <= READ_WORD;
              else
                next_state <= SHIFT_FILTER;
              end if;
            else
              if (unsigned(reading_address_reg) > (unsigned(i_add) + 9)) then
                next_state <= READ_WORD;
              else
                next_state <= SHIFT_FILTER;
              end if;
            end if;
          when READ_WORD =>
            next_state <= SHIFT_WORD;
          when WRITE_RESULT =>
            if (unsigned(writing_address_reg) < unsigned(i_add) + 2 * unsigned(K) + 17) then
              next_state <= SHIFT_WORD;
            else
              next_state <= TERMINATE;
            end if;
          when others => next_state <= RESET;
        end case;
      when others => next_state <= RESET;
    end case;
  end process;

  changing_state: process (current_state) is
  begin
    resetting <= '0';
    starting <= '0';
    asking <= '0';
    reading_k1 <= '0';
    reading_k2 <= '0';
    reading_t <= '0';
    reading_filter <= '0';
    shifting_filters <= '0';
    reading_w <= '0';
    shifting_w <= '0';
    calculating_result <= '0';
    normalizing_result <= '0';
    writing_result <= '0';
    terminating <= '0';
    case current_state is
      when RESET =>
        resetting <= '1';
        o_mem_en <= '0';
        o_mem_we <= '0';
      when START =>
        starting <= '1';
        o_mem_en <= '0';
        o_mem_we <= '0';
      when ASK_MEM =>
        asking <= '1';
        if (prev_state = WRITE_RESULT) then
          o_mem_en <= '1';
          o_mem_we <= '1';
        else
          o_mem_en <= '1';
          o_mem_we <= '0';
        end if;
      when WAIT_MEM =>
        o_mem_en <= '1';
        o_mem_we <= '0';
      when READ_K1 =>
        reading_k1 <= '1';
        o_mem_en <= '1';
        o_mem_we <= '0';
      when READ_K2 =>
        reading_k2 <= '1';
        o_mem_en <= '1';
        o_mem_we <= '0';
      when READ_T =>
        reading_t <= '1';
        o_mem_en <= '1';
        o_mem_we <= '0';
      when READ_FILTER =>
        reading_filter <= '1';
        o_mem_en <= '1';
        o_mem_we <= '0';
      when SHIFT_FILTER =>
        shifting_filters <= '1';
        o_mem_en <= '0';
        o_mem_we <= '0';
      when READ_WORD =>
        reading_w <= '1';
        o_mem_en <= '1';
        o_mem_we <= '0';
      when SHIFT_WORD =>
        shifting_w <= '1';
        o_mem_en <= '1';
        o_mem_we <= '0';
      when CALC_RESULT =>
        calculating_result <= '1';
        o_mem_en <= '0';
        o_mem_we <= '0';
      when NORMALIZE_RESULT =>
        normalizing_result <= '1';
        o_mem_en <= '0';
        o_mem_we <= '0';
      when WRITE_RESULT =>
        writing_result <= '1';
        o_mem_en <= '1';
        o_mem_we <= '1';
      when TERMINATE =>
        terminating <= '1';
        o_mem_en <= '0';
        o_mem_we <= '0';
      when others =>
        o_mem_en <= '0';
        o_mem_we <= '0';
    end case;
  end process;
end architecture;